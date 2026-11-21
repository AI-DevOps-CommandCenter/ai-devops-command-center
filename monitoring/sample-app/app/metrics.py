"""Request metrics for Prometheus.

No `service` label here: Prometheus adds it as a target label at scrape time,
so it is also on `up`. A label with the same name from the app would be
renamed to `exported_service`.
"""

import logging
import time

from prometheus_client import Counter, Histogram, disable_created_metrics
from starlette.routing import Match

UNMATCHED_ROUTE = "unmatched"
SKIPPED_PATHS = {"/metrics"}

disable_created_metrics()

REQUESTS = Counter(
    "http_requests_total",
    "HTTP requests handled, by route template and status code.",
    ["method", "route", "status"],
)
DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds, by route template.",
    ["method", "route"],
)

access_log = logging.getLogger("sample_app.access")


def init_error_series(routes: list[str]) -> None:
    """Create the 5xx series at 0, so error-rate queries have data before the first error."""
    for route in routes:
        REQUESTS.labels(method="GET", route=route, status="500")


def route_template(scope) -> str:
    """Route path such as /api/orders/{order_id}, so label values stay a fixed set."""
    for route in scope["app"].routes:
        match, _ = route.matches(scope)
        if match == Match.FULL:
            return route.path
    return UNMATCHED_ROUTE


def observe(method: str, route: str, status: int, seconds: float) -> None:
    REQUESTS.labels(method=method, route=route, status=str(status)).inc()
    DURATION.labels(method=method, route=route).observe(seconds)
    access_log.info(
        "request",
        extra={"method": method, "route": route, "status": status, "duration_ms": round(seconds * 1000, 1)},
    )


class MetricsMiddleware:
    """ASGI middleware that counts and times every request except /metrics."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope["path"] in SKIPPED_PATHS:
            await self.app(scope, receive, send)
            return

        route = route_template(scope)
        status = 500  # kept if the app raises before sending a response
        start = time.perf_counter()

        async def send_with_status(message):
            nonlocal status
            if message["type"] == "http.response.start":
                status = message["status"]
            await send(message)

        try:
            await self.app(scope, receive, send_with_status)
        finally:
            observe(scope["method"], route, status, time.perf_counter() - start)
