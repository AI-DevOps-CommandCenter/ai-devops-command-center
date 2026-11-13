"""The fixed playbook actions. Each one only touches the allowlisted target.

restart          Docker restart of the target container, then wait for /health.
circuit_breaker  POST /admin/circuit-breaker {"open": true} on the target.
rollback, scale  Not implemented yet (D-MON-6): the allowlist does not grant them.
"""

import logging
import time

import docker
import httpx
import requests

from executor.allowlist import Target

STOP_TIMEOUT_SECONDS = 10  # docker stop grace period before SIGKILL
BREAKER_ATTEMPTS = 3
BREAKER_BACKOFF_SECONDS = 1.0

log = logging.getLogger("executor.actions")


class ActionError(Exception):
    """The action could not be completed; the message is safe to return to the caller."""


class Actions:
    def __init__(self, docker_client, http: httpx.Client, health_timeout_seconds: float = 60,
                 poll_interval_seconds: float = 2, sleep=time.sleep):
        self.docker = docker_client
        self.http = http
        self.health_timeout_seconds = health_timeout_seconds
        self.poll_interval_seconds = poll_interval_seconds
        self.sleep = sleep

    def run(self, action: str, target: Target) -> dict:
        handlers = {"restart": self.restart, "circuit_breaker": self.open_circuit_breaker}
        if action not in handlers:
            raise ActionError(f"Action {action} is not implemented.")
        return handlers[action](target)

    def restart(self, target: Target) -> dict:
        log.info("restart container=%s", target.container)
        try:
            self.docker.containers.get(target.container).restart(timeout=STOP_TIMEOUT_SECONDS)
        except docker.errors.NotFound:
            raise ActionError(f"Container {target.container} not found.")
        except (docker.errors.DockerException, requests.exceptions.RequestException) as error:
            log.warning("restart failed container=%s error=%s", target.container, error)
            raise ActionError(f"Docker restart of {target.container} failed.")
        waited = self.wait_healthy(target)
        return {"container": target.container, "healthy_after_seconds": round(waited, 1)}

    def wait_healthy(self, target: Target) -> float:
        start = time.monotonic()
        while True:
            elapsed = time.monotonic() - start
            try:
                if self.http.get(f"{target.base_url}/health").status_code == 200:
                    return elapsed
            except httpx.TransportError:
                pass  # still starting
            if elapsed >= self.health_timeout_seconds:
                raise ActionError(f"{target.service_name} was not healthy {self.health_timeout_seconds:.0f} s after the restart.")
            self.sleep(self.poll_interval_seconds)

    def open_circuit_breaker(self, target: Target) -> dict:
        url = f"{target.base_url}/admin/circuit-breaker"
        last_problem = ""
        for attempt in range(1, BREAKER_ATTEMPTS + 1):
            log.info("circuit_breaker open url=%s attempt=%d", url, attempt)
            try:
                response = self.http.post(url, json={"open": True})
            except httpx.TransportError as error:
                last_problem = type(error).__name__
            else:
                if response.status_code == 200 and response.json().get("breaker_open") is True:
                    return {"breaker_open": True, "attempts": attempt}
                if response.status_code < 500:
                    raise ActionError(f"{target.service_name} refused to open the circuit breaker (HTTP {response.status_code}).")
                last_problem = f"HTTP {response.status_code}"
            if attempt < BREAKER_ATTEMPTS:
                self.sleep(BREAKER_BACKOFF_SECONDS * attempt)
        raise ActionError(f"Opening the circuit breaker of {target.service_name} failed after {BREAKER_ATTEMPTS} attempts ({last_problem}).")
