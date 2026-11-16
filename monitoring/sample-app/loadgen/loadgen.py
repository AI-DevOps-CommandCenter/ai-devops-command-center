"""Steady traffic for sample-app, so rate() queries always have data.

Each request has a timeout and is never retried: a failure is counted and the
loop moves on. A summary of outcomes is logged every REPORT_EVERY_SECONDS.
"""

import logging
import os
import random
import signal
import threading
import time
from collections import Counter

import httpx

PATHS = ["/api/orders"] + [f"/api/orders/{order_id}" for order_id in range(1, 11)]

log = logging.getLogger("loadgen")


def env_float(name: str, default: float, low: float, high: float) -> float:
    value = float(os.getenv(name, str(default)))
    if not low <= value <= high:
        raise ValueError(f"{name} must be between {low} and {high}, got {value}")
    return value


def send_one(client: httpx.Client, path: str) -> str:
    """Send one GET and return the outcome: the status code, or the error kind."""
    try:
        return str(client.get(path).status_code)
    except httpx.TimeoutException:
        return "timeout"
    except httpx.TransportError:
        return "connect_error"


def run(client: httpx.Client, rps: float, report_every: float, stop: threading.Event, max_requests: int | None = None) -> Counter:
    outcomes: Counter = Counter()
    interval = 1.0 / rps
    last_report = time.monotonic()
    sent = 0
    while not stop.is_set() and (max_requests is None or sent < max_requests):
        outcomes[send_one(client, random.choice(PATHS))] += 1
        sent += 1
        if time.monotonic() - last_report >= report_every:
            log.info("sent=%d outcomes=%s", sent, dict(outcomes))
            last_report = time.monotonic()
        stop.wait(interval)
    log.info("stopped sent=%d outcomes=%s", sent, dict(outcomes))
    return outcomes


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)  # the periodic summary replaces per-request lines
    target = os.getenv("TARGET_URL", "http://sample-app:8000")
    rps = env_float("LOADGEN_RPS", 5, 0.1, 50)
    timeout = env_float("REQUEST_TIMEOUT_SECONDS", 2, 0.1, 30)
    report_every = env_float("REPORT_EVERY_SECONDS", 30, 1, 3600)

    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())

    log.info("target=%s rps=%s timeout=%ss retries=0", target, rps, timeout)
    with httpx.Client(base_url=target, timeout=timeout) as client:
        run(client, rps, report_every, stop)


if __name__ == "__main__":
    main()
