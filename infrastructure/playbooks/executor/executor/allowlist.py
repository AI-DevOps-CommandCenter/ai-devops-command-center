"""Which services the executor may act on, and with which actions.

Read once at startup from a JSON file in the repository. Nothing in a request
can add a service, a container or an action.
"""

import json
import re
from dataclasses import dataclass
from pathlib import Path

ACTIONS = ("restart", "rollback", "scale", "circuit_breaker")
SERVICE_PATTERN = re.compile(r"^[A-Za-z0-9_.:-]{1,100}$")


@dataclass(frozen=True)
class Target:
    service_name: str
    container: str
    base_url: str
    actions: frozenset[str]


def load_allowlist(path: Path) -> dict[str, Target]:
    raw = json.loads(path.read_text())
    targets = {}
    for service_name, entry in raw.items():
        if not SERVICE_PATTERN.match(service_name):
            raise ValueError(f"Invalid service name in allowlist: {service_name!r}")
        unknown = set(entry["actions"]) - set(ACTIONS)
        if unknown:
            raise ValueError(f"Unknown actions for {service_name}: {sorted(unknown)}")
        targets[service_name] = Target(
            service_name=service_name,
            container=entry["container"],
            base_url=entry["base_url"].rstrip("/"),
            actions=frozenset(entry["actions"]),
        )
    return targets
