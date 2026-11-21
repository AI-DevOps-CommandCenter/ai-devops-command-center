"""sample-app: a small orders API used as the target of the monitoring stack.

Normal endpoints:  GET /api/orders, GET /api/orders/{order_id}, GET /health (with the release version)
Prometheus:        GET /metrics
Admin (internal):  GET/POST /admin/fault, POST /admin/circuit-breaker

Release (set in the image, see Dockerfile):
  APP_VERSION     the version string reported by /health and logged at startup
  RELEASE_FAULT   optional built-in fault active from startup, "errors:0.5" or
                  "latency:0.3". It simulates a bad release: a restart does not
                  clear it, only a rollback to an image without it does.

The admin endpoints have no authentication. The container port must not be
published to the host; only services on the Docker network can reach them.
"""

import logging
import os
from typing import Literal

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from pydantic import BaseModel, Field

from app.faults import DependencyError, FaultState, call_inventory
from app.logs import setup_logging
from app.metrics import MetricsMiddleware, init_error_series

ORDERS = {
    order_id: {"id": order_id, "item": f"item-{order_id}", "quantity": order_id % 3 + 1}
    for order_id in range(1, 11)
}
API_ROUTES = ["/api/orders", "/api/orders/{order_id}"]

log = logging.getLogger("sample_app")


class FaultRequest(BaseModel):
    mode: Literal["errors", "latency", "off"]
    rate: float = Field(default=1.0, ge=0.0, le=1.0)


class BreakerRequest(BaseModel):
    open: bool


async def with_stock(request: Request, order: dict) -> dict:
    """Add the stock level from the inventory dependency, unless the breaker is open."""
    faults: FaultState = request.app.state.faults
    if faults.breaker_open:
        return {**order, "stock": None, "degraded": True}
    try:
        stock = await call_inventory(faults, request.app.state.fault_latency_seconds)
    except DependencyError:
        log.exception("inventory call failed")
        raise HTTPException(status_code=500, detail="inventory unavailable")
    return {**order, "stock": stock, "degraded": False}


def parse_release_fault(value: str) -> tuple[str, float] | None:
    """Parse RELEASE_FAULT ("errors:0.5", "latency:0.3"); empty means none."""
    value = value.strip()
    if not value:
        return None
    mode, _, rate = value.partition(":")
    if mode not in ("errors", "latency"):
        raise ValueError(f"RELEASE_FAULT mode must be errors or latency, got {mode!r}")
    rate_value = float(rate or "1.0")
    if not 0.0 <= rate_value <= 1.0:
        raise ValueError(f"RELEASE_FAULT rate must be between 0 and 1, got {rate_value}")
    return mode, rate_value


def create_app(fault_latency_seconds: float | None = None) -> FastAPI:
    service = os.getenv("SERVICE_NAME", "sample-app")
    version = os.getenv("APP_VERSION", "dev")
    setup_logging(service, os.getenv("LOG_LEVEL", "INFO"), version)
    release_fault = parse_release_fault(os.getenv("RELEASE_FAULT", ""))

    app = FastAPI(title=service, docs_url=None, redoc_url=None, openapi_url=None)
    app.state.version = version
    app.state.faults = FaultState()
    if release_fault:
        app.state.faults.set_fault(*release_fault)
    log.info("release started")
    app.state.fault_latency_seconds = (
        fault_latency_seconds
        if fault_latency_seconds is not None
        else float(os.getenv("FAULT_LATENCY_SECONDS", "1.5"))
    )
    app.add_middleware(MetricsMiddleware)
    init_error_series(API_ROUTES)

    @app.get("/health")
    async def health(request: Request):
        return {"status": "ok", "version": request.app.state.version}

    @app.get("/metrics")
    async def metrics():
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

    @app.get("/api/orders")
    async def list_orders(request: Request):
        await with_stock(request, {})
        return {"orders": list(ORDERS.values())}

    @app.get("/api/orders/{order_id}")
    async def get_order(order_id: int, request: Request):
        order = ORDERS.get(order_id)
        if order is None:
            raise HTTPException(status_code=404, detail="order not found")
        return await with_stock(request, order)

    @app.get("/admin/fault")
    async def get_fault(request: Request):
        return request.app.state.faults.snapshot()

    @app.post("/admin/fault")
    async def set_fault(body: FaultRequest, request: Request):
        faults: FaultState = request.app.state.faults
        faults.set_fault(body.mode, body.rate)
        log.warning("fault changed", extra={"mode": faults.mode, "rate": faults.rate})
        return faults.snapshot()

    @app.post("/admin/circuit-breaker")
    async def set_breaker(body: BreakerRequest, request: Request):
        faults: FaultState = request.app.state.faults
        faults.breaker_open = body.open
        log.warning("circuit breaker changed", extra={"open": body.open})
        return faults.snapshot()

    return app


app = create_app()
