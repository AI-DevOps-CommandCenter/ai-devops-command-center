"""The fixed playbook actions. Each one only touches the allowlisted target.

A target has one main container (the compose service) and, after `scale`,
replica containers labelled REPLICA_LABEL=<service>. "Instances" means all of
them. Every health check goes to one container by name, not to the shared
service alias, so the answer comes from the container that was just changed.

restart          Docker restart of every instance, then wait for /health.
circuit_breaker  POST /admin/circuit-breaker {"open": true} on every instance.
rollback         Recreate every instance from the allowlisted rollback_image
                 (same environment, labels, networks and aliases), wait for
                 /health, remove the old container. If the new container does
                 not become healthy, it is removed and the old one is restored.
scale            Add replica containers until the target has max_replicas
                 instances. Replicas share the service's network alias, so the
                 load balancer and Prometheus find them through DNS.
"""

import logging
import time
from urllib.parse import urlsplit

import docker
import httpx
import requests

from executor.allowlist import Target

STOP_TIMEOUT_SECONDS = 10  # docker stop grace period before SIGKILL
BREAKER_ATTEMPTS = 3
BREAKER_BACKOFF_SECONDS = 1.0
REPLICA_LABEL = "dc.executor.replica-of"
# Labels a replica must not copy: they would make docker compose treat the
# replica as its own container (and remove or recreate it).
COMPOSE_LABEL_PREFIX = "com.docker.compose."
# Kept on replicas so Promtail still sets the `service` label on their logs.
COMPOSE_SERVICE_LABEL = "com.docker.compose.service"

log = logging.getLogger("executor.actions")

DOCKER_ERRORS = (docker.errors.DockerException, requests.exceptions.RequestException)


class ActionError(Exception):
    """The action could not be completed; the message is safe to return to the caller."""


class Actions:
    def __init__(self, docker_client, http: httpx.Client, health_timeout_seconds: float = 60,
                 poll_interval_seconds: float = 2, sleep=time.sleep, clock=time.time):
        self.docker = docker_client
        self.http = http
        self.health_timeout_seconds = health_timeout_seconds
        self.poll_interval_seconds = poll_interval_seconds
        self.sleep = sleep
        self.clock = clock

    def run(self, action: str, target: Target) -> dict:
        handlers = {
            "restart": self.restart,
            "circuit_breaker": self.open_circuit_breaker,
            "rollback": self.rollback,
            "scale": self.scale,
        }
        if action not in handlers:
            raise ActionError(f"Action {action} is not implemented.")
        return handlers[action](target)

    # --- instances -------------------------------------------------------------

    def main_container(self, target: Target):
        try:
            return self.docker.containers.get(target.container)
        except docker.errors.NotFound:
            raise ActionError(f"Container {target.container} not found.")
        except DOCKER_ERRORS as error:
            log.warning("docker get failed container=%s error=%s", target.container, error)
            raise ActionError(f"Docker could not read container {target.container}.")

    def replicas(self, target: Target) -> list:
        try:
            found = self.docker.containers.list(all=True, filters={"label": f"{REPLICA_LABEL}={target.service_name}"})
        except DOCKER_ERRORS as error:
            log.warning("docker list failed service=%s error=%s", target.service_name, error)
            raise ActionError(f"Docker could not list the replicas of {target.service_name}.")
        return sorted(found, key=lambda c: c.name)

    def instance_url(self, target: Target, container_name: str) -> str:
        """http://<container name>:<port of base_url>, reachable on the shared network."""
        parts = urlsplit(target.base_url)
        port = parts.port or (443 if parts.scheme == "https" else 80)
        return f"{parts.scheme}://{container_name}:{port}"

    def wait_healthy(self, target: Target, container_name: str, after: str = "the restart") -> float:
        url = f"{self.instance_url(target, container_name)}/health"
        start = time.monotonic()
        while True:
            elapsed = time.monotonic() - start
            try:
                if self.http.get(url).status_code == 200:
                    return elapsed
            except httpx.TransportError:
                pass  # still starting
            if elapsed >= self.health_timeout_seconds:
                raise ActionError(
                    f"{container_name} was not healthy {self.health_timeout_seconds:.0f} s after {after}.")
            self.sleep(self.poll_interval_seconds)

    # --- restart ---------------------------------------------------------------

    def restart(self, target: Target) -> dict:
        instances = [self.main_container(target), *self.replicas(target)]
        healthy_after = {}
        for container in instances:
            log.info("restart container=%s", container.name)
            try:
                container.restart(timeout=STOP_TIMEOUT_SECONDS)
            except DOCKER_ERRORS as error:
                log.warning("restart failed container=%s error=%s", container.name, error)
                raise ActionError(f"Docker restart of {container.name} failed.")
            healthy_after[container.name] = round(self.wait_healthy(target, container.name), 1)
        return {
            "container": target.container,
            "healthy_after_seconds": healthy_after[target.container],
            "instances": len(instances),
        }

    # --- circuit breaker -------------------------------------------------------

    def open_circuit_breaker(self, target: Target) -> dict:
        names = [self.main_container(target).name, *(c.name for c in self.replicas(target))]
        attempts = 0
        for name in names:
            attempts = max(attempts, self.open_breaker_on(target, name))
        return {"breaker_open": True, "attempts": attempts, "instances": len(names)}

    def open_breaker_on(self, target: Target, container_name: str) -> int:
        url = f"{self.instance_url(target, container_name)}/admin/circuit-breaker"
        last_problem = ""
        for attempt in range(1, BREAKER_ATTEMPTS + 1):
            log.info("circuit_breaker open url=%s attempt=%d", url, attempt)
            try:
                response = self.http.post(url, json={"open": True})
            except httpx.TransportError as error:
                last_problem = type(error).__name__
            else:
                if response.status_code == 200 and response.json().get("breaker_open") is True:
                    return attempt
                if response.status_code < 500:
                    raise ActionError(
                        f"{container_name} refused to open the circuit breaker (HTTP {response.status_code}).")
                last_problem = f"HTTP {response.status_code}"
            if attempt < BREAKER_ATTEMPTS:
                self.sleep(BREAKER_BACKOFF_SECONDS * attempt)
        raise ActionError(
            f"Opening the circuit breaker of {container_name} failed after {BREAKER_ATTEMPTS} attempts ({last_problem}).")

    # --- rollback --------------------------------------------------------------

    def rollback(self, target: Target) -> dict:
        if not target.rollback_image:
            raise ActionError(f"No rollback image is configured for {target.service_name}.")
        try:
            image = self.docker.images.get(target.rollback_image)
        except docker.errors.ImageNotFound:
            raise ActionError(f"Rollback image {target.rollback_image} does not exist on this host.")
        except DOCKER_ERRORS as error:
            log.warning("docker image get failed image=%s error=%s", target.rollback_image, error)
            raise ActionError(f"Docker could not read image {target.rollback_image}.")

        main = self.main_container(target)
        previous_image = main.attrs["Config"]["Image"]
        if main.image.id == image.id:
            log.info("rollback skipped container=%s already on %s", main.name, target.rollback_image)
            return {"container": main.name, "image": target.rollback_image, "previous_image": previous_image,
                    "changed": False, "instances": 1 + len(self.replicas(target))}

        swapped = [self.replace_container(target, main, target.rollback_image)]
        for replica in self.replicas(target):
            swapped.append(self.replace_container(target, replica, target.rollback_image))
        return {
            "container": main.name,
            "image": target.rollback_image,
            "previous_image": previous_image,
            "changed": True,
            "instances": len(swapped),
            "healthy_after_seconds": swapped[0],
        }

    def replace_container(self, target: Target, old, image: str) -> float:
        """Recreate `old` from `image` under the same name; restore `old` if that fails."""
        name = old.name
        spec = self.container_spec(old)
        backup_name = f"{name}-before-rollback-{int(self.clock())}"
        log.info("rollback container=%s image=%s backup=%s", name, image, backup_name)
        try:
            old.stop(timeout=STOP_TIMEOUT_SECONDS)
            old.rename(backup_name)
        except DOCKER_ERRORS as error:
            log.warning("rollback could not set aside container=%s error=%s", name, error)
            self.try_start(old)
            raise ActionError(f"Rollback of {name} failed before any change (Docker stop/rename).")

        new = None
        try:
            new = self.create_container(image, name, spec)
            new.start()
            healthy_after = round(self.wait_healthy(target, name, after="the rollback"), 1)
        except (ActionError, *DOCKER_ERRORS) as error:
            log.warning("rollback failed container=%s error=%s; restoring the previous container", name, error)
            if self.restore(old, new, name):
                raise ActionError(f"Rollback of {name} to {image} failed; the previous container was restored.")
            raise ActionError(f"Rollback of {name} to {image} failed and the previous container "
                              f"could not be restored (it is kept as {backup_name}).")
        self.try_remove(old)
        return healthy_after

    def restore(self, old, new, name: str) -> bool:
        """Remove the failed new container and bring the old one back under its name."""
        if new is not None:
            self.try_remove(new, force=True)
        try:
            old.rename(name)
            old.start()
            return True
        except DOCKER_ERRORS as error:
            log.error("restore failed container=%s error=%s", name, error)
            return False

    # --- scale -----------------------------------------------------------------

    def scale(self, target: Target) -> dict:
        if target.max_replicas < 2:
            raise ActionError(f"Scaling is not configured for {target.service_name}.")
        main = self.main_container(target)
        existing = self.replicas(target)
        before = 1 + len(existing)
        by_name = {c.name: c for c in existing}
        spec = self.container_spec(main, for_replica_of=target.service_name)
        image = main.attrs["Config"]["Image"]

        added, started = [], []
        for index in range(2, target.max_replicas + 1):
            name = f"{target.container}-{index}"
            current = by_name.get(name)
            try:
                if current is not None:
                    if current.status == "running":
                        continue
                    log.info("scale start existing replica=%s", name)
                    current.start()
                    started.append(current)
                else:
                    log.info("scale create replica=%s image=%s", name, image)
                    current = self.create_container(image, name, spec)
                    added.append(current)
                    current.start()
                self.wait_healthy(target, name, after="the scale-up")
            except (ActionError, *DOCKER_ERRORS) as error:
                log.warning("scale failed replica=%s error=%s; removing the replicas added by this run", name, error)
                for container in added:
                    self.try_remove(container, force=True)
                raise ActionError(f"Scaling {target.service_name} failed at {name}; replicas added by this run were removed.")
        return {
            "service_name": target.service_name,
            "instances_before": before,
            "instances_after": target.max_replicas,
            "added": [c.name for c in added] + [c.name for c in started],
            "image": image,
        }

    # --- container helpers -----------------------------------------------------

    def container_spec(self, container, for_replica_of: str | None = None) -> dict:
        """What to copy when creating a container like `container` (not its image settings)."""
        attrs = container.attrs
        config, host = attrs["Config"], attrs["HostConfig"]
        image_config = container.image.attrs.get("Config") or {}
        image_env = set(image_config.get("Env") or [])
        labels = dict(config.get("Labels") or {})
        for key, value in (image_config.get("Labels") or {}).items():
            if labels.get(key) == value:
                del labels[key]
        if for_replica_of:
            labels = {k: v for k, v in labels.items()
                      if not k.startswith(COMPOSE_LABEL_PREFIX) or k == COMPOSE_SERVICE_LABEL}
            labels[REPLICA_LABEL] = for_replica_of
        networks = {}
        for network, settings in (attrs["NetworkSettings"].get("Networks") or {}).items():
            skip = {container.name, container.id[:12]}
            aliases = [a for a in (settings or {}).get("Aliases") or [] if a not in skip]
            networks[network] = aliases
        command = config.get("Cmd")
        return {
            # Environment set on the container, not inherited from the old image:
            # the new image brings its own APP_VERSION / RELEASE_FAULT.
            "environment": [e for e in config.get("Env") or [] if e not in image_env],
            "labels": labels,
            "command": command if command != image_config.get("Cmd") else None,
            "healthcheck": config.get("Healthcheck"),
            "restart_policy": host.get("RestartPolicy"),
            "networks": networks,
        }

    def create_container(self, image: str, name: str, spec: dict):
        networks = spec["networks"]
        if not networks:
            raise ActionError(f"Container {name} has no network to join.")
        first, *others = networks
        kwargs = {
            "name": name,
            "environment": spec["environment"],
            "labels": spec["labels"],
            "network": first,
            "networking_config": {first: self.docker.api.create_endpoint_config(aliases=networks[first])},
        }
        if spec["command"]:
            kwargs["command"] = spec["command"]
        if spec["healthcheck"]:
            kwargs["healthcheck"] = spec["healthcheck"]
        if spec["restart_policy"] and spec["restart_policy"].get("Name"):
            kwargs["restart_policy"] = {"Name": spec["restart_policy"]["Name"]}
        container = self.docker.containers.create(image, **kwargs)
        for network in others:
            self.docker.networks.get(network).connect(container, aliases=networks[network])
        return container

    @staticmethod
    def try_start(container) -> None:
        try:
            container.start()
        except DOCKER_ERRORS as error:
            log.error("could not start container=%s error=%s", getattr(container, "name", "?"), error)

    @staticmethod
    def try_remove(container, force: bool = False) -> None:
        try:
            container.remove(force=force)
        except DOCKER_ERRORS as error:
            log.warning("could not remove container=%s error=%s", getattr(container, "name", "?"), error)
