import json
import secrets
import time

import docker
import httpx

from executor.actions import Actions
from executor.allowlist import Target
from executor.app import EXECUTE_PATH, create_app
from executor.signing import compute_signature

SECRET = "test-only-secret-0123456789abcdef0123"
RUN_ID = "11111111-1111-4111-8111-111111111111"
TARGET = Target("sample-app", "dc-sample-app", "http://sample-app:8000", frozenset({"restart", "circuit_breaker"}))


class FakeContainer:
    def __init__(self):
        self.restarts = []

    def restart(self, timeout):
        self.restarts.append(timeout)


class FakeDocker:
    def __init__(self, names=("dc-sample-app",)):
        self.by_name = {name: FakeContainer() for name in names}
        self.containers = self

    def get(self, name):
        if name not in self.by_name:
            raise docker.errors.NotFound(f"No such container: {name}")
        return self.by_name[name]


def sample_app_transport(breaker_statuses=None):
    """Mock sample-app: /health is 200; circuit-breaker answers the given statuses in turn."""
    statuses = iter(breaker_statuses or [200])
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        if request.url.path == "/health":
            return httpx.Response(200, json={"status": "ok"})
        status = next(statuses)
        if isinstance(status, Exception):
            raise status
        return httpx.Response(status, json={"breaker_open": status == 200})

    return httpx.MockTransport(handler), calls


def make_actions(docker_client=None, transport=None, health_timeout_seconds=1.0):
    transport = transport or sample_app_transport()[0]
    return Actions(
        docker_client=docker_client or FakeDocker(),
        http=httpx.Client(transport=transport),
        health_timeout_seconds=health_timeout_seconds,
        poll_interval_seconds=0,
        sleep=lambda seconds: None,
    )


def make_app(actions=None, secret=SECRET):
    return create_app(secret, {"sample-app": TARGET}, actions or make_actions())


def signed(body, path=EXECUTE_PATH, secret=SECRET, timestamp=None, nonce=None):
    """Return (raw_body, headers) signed like n8n's signedBackendRequest()."""
    raw = body if isinstance(body, str) else json.dumps(body)
    timestamp = int(time.time()) if timestamp is None else timestamp
    nonce = nonce or secrets.token_urlsafe(18)
    headers = {
        "Content-Type": "application/json",
        "X-DC-Timestamp": str(timestamp),
        "X-DC-Nonce": nonce,
        "X-DC-Signature": compute_signature(secret, timestamp, nonce, "POST", path, raw),
    }
    return raw, headers


def request_body(action="restart", service_name="sample-app", run_id=RUN_ID, **extra):
    return {"action": action, "service_name": service_name, "playbook_run_id": run_id, **extra}
