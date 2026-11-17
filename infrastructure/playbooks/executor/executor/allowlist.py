"""Which services the executor may act on, and with which actions.

Read once at startup from a JSON file in the repository. Nothing in a request
can add a service, a container, an image or an action.

Per service:
  container       the main container (the compose service's container_name)
  base_url        scheme and port of the service; the host part is the shared alias
  actions         subset of ACTIONS
  rollback_image  required for "rollback": the known-good image to go back to
  max_replicas    required for "scale": total instances after a scale-up (2-5)
"""

import json
import re
from dataclasses import dataclass
from pathlib import Path

ACTIONS = ("restart", "rollback", "scale", "circuit_breaker")
SERVICE_PATTERN = re.compile(r"^[A-Za-z0-9_.:-]{1,100}$")
IMAGE_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._/-]{0,127}:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")
MAX_REPLICAS_LIMIT = 5


@dataclass(frozen=True)
class Target:
    service_name: str
    container: str
    base_url: str
    actions: frozenset[str]
    rollback_image: str | None = None
    max_replicas: int = 1


def load_allowlist(path: Path) -> dict[str, Target]:
    raw = json.loads(path.read_text())
    targets = {}
    for service_name, entry in raw.items():
        if not SERVICE_PATTERN.match(service_name):
            raise ValueError(f"Invalid service name in allowlist: {service_name!r}")
        actions = set(entry["actions"])
        unknown = actions - set(ACTIONS)
        if unknown:
            raise ValueError(f"Unknown actions for {service_name}: {sorted(unknown)}")

        rollback_image = entry.get("rollback_image")
        if "rollback" in actions and not rollback_image:
            raise ValueError(f"{service_name}: rollback needs rollback_image")
        if rollback_image is not None and not IMAGE_PATTERN.match(rollback_image):
            raise ValueError(f"{service_name}: rollback_image must be name:tag, got {rollback_image!r}")

        max_replicas = entry.get("max_replicas", 1)
        if not isinstance(max_replicas, int) or not 1 <= max_replicas <= MAX_REPLICAS_LIMIT:
            raise ValueError(f"{service_name}: max_replicas must be an integer from 1 to {MAX_REPLICAS_LIMIT}")
        if "scale" in actions and max_replicas < 2:
            raise ValueError(f"{service_name}: scale needs max_replicas of at least 2")

        targets[service_name] = Target(
            service_name=service_name,
            container=entry["container"],
            base_url=entry["base_url"].rstrip("/"),
            actions=frozenset(actions),
            rollback_image=rollback_image,
            max_replicas=max_replicas,
        )
    return targets
