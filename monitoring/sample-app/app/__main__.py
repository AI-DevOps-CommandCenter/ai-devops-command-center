"""Run sample-app with one uvicorn worker (prometheus_client keeps metrics per process)."""

import os

import uvicorn

from app.main import app


def main() -> None:
    uvicorn.run(
        app,
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "8000")),
        log_config=None,  # keep the JSON handler from app.logs for uvicorn's own loggers
        access_log=False,  # MetricsMiddleware writes one access line per request
    )


if __name__ == "__main__":
    main()
