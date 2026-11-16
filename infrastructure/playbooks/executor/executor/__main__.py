"""Start the executor from environment settings."""

import logging
import os
from pathlib import Path

import docker
import httpx
import uvicorn

from executor.actions import Actions
from executor.allowlist import load_allowlist
from executor.app import create_app

DOCKER_API_TIMEOUT_SECONDS = 60
HTTP_TIMEOUT_SECONDS = 5


def main() -> None:
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format="%(asctime)s %(levelname)s %(name)s %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)

    targets = load_allowlist(Path(os.getenv("EXECUTOR_ALLOWLIST", "allowlist.json")))
    actions = Actions(
        docker_client=docker.from_env(timeout=DOCKER_API_TIMEOUT_SECONDS),
        http=httpx.Client(timeout=HTTP_TIMEOUT_SECONDS),
        health_timeout_seconds=float(os.getenv("HEALTH_TIMEOUT_SECONDS", "60")),
    )
    app = create_app(os.getenv("EXECUTOR_SIGNING_SECRET"), targets, actions)
    logging.getLogger("executor").info("allowlist: %s", {name: sorted(t.actions) for name, t in targets.items()})
    uvicorn.run(app, host=os.getenv("HOST", "127.0.0.1"), port=int(os.getenv("PORT", "9095")), access_log=False)


if __name__ == "__main__":
    main()
