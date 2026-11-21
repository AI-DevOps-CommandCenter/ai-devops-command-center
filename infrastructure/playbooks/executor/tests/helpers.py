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


FULL_TARGET = Target("sample-app", "dc-sample-app", "http://sample-app:8000",
                     frozenset({"restart", "circuit_breaker", "rollback", "scale"}),
                     rollback_image="dc-sample-app:stable", max_replicas=3)

IMAGE_ENV = ["PATH=/usr/local/bin", "APP_VERSION=v2", "RELEASE_FAULT=errors:0.5"]
COMPOSE_LABELS = {
    "com.docker.compose.project": "dc-monitoring",
    "com.docker.compose.service": "sample-app",
    "com.docker.compose.config-hash": "abc",
}


class FakeImage:
    def __init__(self, image_id, env=None, cmd=None, labels=None):
        self.id = image_id
        self.attrs = {"Config": {"Env": list(env or []), "Cmd": cmd or ["python", "-m", "app"], "Labels": labels}}


class FakeContainer:
    """Enough of docker.models.containers.Container for the executor actions."""

    def __init__(self, docker, name, image_ref="dc-sample-app:dev", image=None, env=None, labels=None,
                 networks=None, status="running", command=None):
        self.docker = docker
        self.name = name
        self.id = f"{abs(hash(name)):012x}{'0' * 52}"[:64]
        self.status = status
        self.image = image or docker.images.get(image_ref)
        self.restarts = []
        self.events = []
        self.removed = False
        default_networks = {"dc-monitoring_default": {"Aliases": ["sample-app", name, self.id[:12]]}}
        self.attrs = {
            "Config": {
                "Image": image_ref,
                "Env": list(self.image.attrs["Config"]["Env"]) + list(env or ["SERVICE_NAME=sample-app"]),
                "Labels": dict(COMPOSE_LABELS if labels is None else labels),
                "Cmd": command or self.image.attrs["Config"]["Cmd"],
                "Healthcheck": {"Test": ["CMD", "true"]},
            },
            "HostConfig": {"RestartPolicy": {"Name": "unless-stopped", "MaximumRetryCount": 0}},
            "NetworkSettings": {"Networks": default_networks if networks is None else networks},
        }

    def restart(self, timeout):
        self.restarts.append(timeout)
        self.docker.log.append(("restart", self.name))

    def stop(self, timeout):
        self.status = "exited"
        self.docker.log.append(("stop", self.name))
        if self.docker.fail_on == ("stop", self.name):
            raise docker.errors.APIError("stop failed")

    def start(self):
        if self.docker.fail_on == ("start", self.name):
            raise docker.errors.APIError("start failed")
        self.status = "running"
        self.docker.log.append(("start", self.name))

    def rename(self, new_name):
        self.docker.log.append(("rename", self.name, new_name))
        del self.docker.by_name[self.name]
        self.name = new_name
        self.docker.by_name[new_name] = self

    def remove(self, force=False):
        self.removed = True
        self.docker.log.append(("remove", self.name))
        self.docker.by_name.pop(self.name, None)


class FakeNetwork:
    def __init__(self, docker, name):
        self.docker, self.name = docker, name

    def connect(self, container, aliases=None):
        self.docker.log.append(("connect", self.name, container.name, tuple(aliases or ())))


class FakeApi:
    @staticmethod
    def create_endpoint_config(aliases=None):
        return {"Aliases": list(aliases or [])}


class FakeDocker:
    """In-memory Docker: containers by name, a few images, a log of every change."""

    def __init__(self, names=("dc-sample-app",), images=None):
        self.images_by_ref = images or {
            "dc-sample-app:dev": FakeImage("sha256:dev", IMAGE_ENV),
            "dc-sample-app:stable": FakeImage("sha256:stable", ["PATH=/usr/local/bin", "APP_VERSION=v1", "RELEASE_FAULT="]),
        }
        self.by_name = {}
        self.log = []
        self.created = []
        self.fail_on = None
        self.containers = FakeContainers(self)
        self.images = FakeImages(self)
        self.networks = FakeNetworks(self)
        self.api = FakeApi()
        for name in names:
            self.by_name[name] = FakeContainer(self, name)

    def get(self, name):  # kept for older tests: docker_client.get(...)
        return self.containers.get(name)


class FakeContainers:
    def __init__(self, docker):
        self.docker = docker

    def get(self, name):
        if name not in self.docker.by_name:
            raise docker.errors.NotFound(f"No such container: {name}")
        return self.docker.by_name[name]

    def list(self, all=False, filters=None):
        key, _, value = (filters or {}).get("label", "").partition("=")
        found = [c for c in self.docker.by_name.values()
                 if (all or c.status == "running") and (not key or c.attrs["Config"]["Labels"].get(key) == value)]
        return found

    def create(self, image, name, environment, labels, network, networking_config, **kwargs):
        if self.docker.fail_on == ("create", name):
            raise docker.errors.APIError("create failed")
        if name in self.docker.by_name:
            raise docker.errors.APIError(f"Conflict: name {name} in use")
        container = FakeContainer(
            self.docker, name, image_ref=image, image=self.docker.images.get(image), env=[], labels=labels,
            networks={network: {"Aliases": networking_config[network]["Aliases"]}}, status="created",
        )
        container.attrs["Config"]["Env"] = list(container.image.attrs["Config"]["Env"]) + list(environment)
        container.create_kwargs = {"environment": environment, "labels": labels, "network": network,
                                   "networking_config": networking_config, **kwargs}
        self.docker.by_name[name] = container
        self.docker.created.append(container)
        self.docker.log.append(("create", name, image))
        return container


class FakeImages:
    def __init__(self, docker):
        self.docker = docker

    def get(self, ref):
        if ref not in self.docker.images_by_ref:
            raise docker.errors.ImageNotFound(f"No such image: {ref}")
        return self.docker.images_by_ref[ref]


class FakeNetworks:
    def __init__(self, docker):
        self.docker = docker

    def get(self, name):
        return FakeNetwork(self.docker, name)


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
