import json
import logging
import sys
import time

import pytest
from fastapi.testclient import TestClient
from prometheus_client import REGISTRY

from app.logs import JsonFormatter
from app.main import create_app

ORDER_ROUTE = "/api/orders/{order_id}"


class ListHandler(logging.Handler):
    def __init__(self):
        super().__init__()
        self.records: list[logging.LogRecord] = []

    def emit(self, record):
        self.records.append(record)


@pytest.fixture
def client():
    return TestClient(create_app(fault_latency_seconds=0.05))


@pytest.fixture
def app_log():
    handler = ListHandler()
    logger = logging.getLogger("sample_app")
    logger.addHandler(handler)
    yield handler
    logger.removeHandler(handler)


def requests_count(route: str, status: int, method: str = "GET") -> float:
    labels = {"method": method, "route": route, "status": str(status)}
    return REGISTRY.get_sample_value("http_requests_total", labels) or 0.0


def duration_count(route: str, method: str = "GET") -> float:
    labels = {"method": method, "route": route}
    return REGISTRY.get_sample_value("http_request_duration_seconds_count", labels) or 0.0


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_order_is_counted_under_route_template(client):
    before_ok, before_duration = requests_count(ORDER_ROUTE, 200), duration_count(ORDER_ROUTE)

    response = client.get("/api/orders/3")

    assert response.status_code == 200
    assert response.json()["degraded"] is False
    assert requests_count(ORDER_ROUTE, 200) == before_ok + 1
    assert duration_count(ORDER_ROUTE) == before_duration + 1


def test_unknown_order_is_404_not_5xx(client):
    before = requests_count(ORDER_ROUTE, 404)
    assert client.get("/api/orders/999").status_code == 404
    assert requests_count(ORDER_ROUTE, 404) == before + 1


def test_unknown_path_uses_fixed_route_label(client):
    before = requests_count("unmatched", 404)
    client.get("/does-not-exist/12345")
    assert requests_count("unmatched", 404) == before + 1


def test_metrics_scrapes_are_not_counted(client):
    client.get("/metrics")
    assert requests_count("/metrics", 200) == 0.0


def test_metrics_exposition(client):
    body = client.get("/metrics").text

    assert "http_requests_total{" in body
    assert "http_request_duration_seconds_bucket{" in body
    # 5xx series exist before any error, so error-rate queries are never empty.
    assert 'http_requests_total{method="GET",route="/api/orders",status="500"}' in body
    # Prometheus adds `service` as a target label; the app must not export one.
    assert "service=" not in body


@pytest.mark.skipif(not sys.platform.startswith("linux"), reason="process metrics exist only on Linux")
def test_process_metrics_for_workflow_03_defaults(client):
    body = client.get("/metrics").text
    assert "process_cpu_seconds_total" in body
    assert "process_resident_memory_bytes" in body


def test_error_fault_returns_500_and_logs_error(client, app_log):
    before = requests_count(ORDER_ROUTE, 500)
    client.post("/admin/fault", json={"mode": "errors", "rate": 1.0})

    response = client.get("/api/orders/1")

    assert response.status_code == 500
    assert response.json() == {"detail": "inventory unavailable"}
    assert requests_count(ORDER_ROUTE, 500) == before + 1
    errors = [r for r in app_log.records if r.levelno == logging.ERROR]
    assert errors and "DependencyError" in str(errors[0].exc_info[0])


def test_open_breaker_bypasses_failing_dependency(client):
    client.post("/admin/fault", json={"mode": "errors", "rate": 1.0})
    client.post("/admin/circuit-breaker", json={"open": True})

    response = client.get("/api/orders/1")

    assert response.status_code == 200
    assert response.json()["degraded"] is True


def test_fault_off_restores_normal_responses(client):
    client.post("/admin/fault", json={"mode": "errors", "rate": 1.0})
    client.post("/admin/fault", json={"mode": "off"})

    assert client.get("/admin/fault").json() == {"mode": "off", "rate": 0.0, "breaker_open": False}
    assert client.get("/api/orders").status_code == 200


def test_latency_fault_slows_requests(client):
    client.post("/admin/fault", json={"mode": "latency", "rate": 1.0})

    start = time.perf_counter()
    response = client.get("/api/orders/2")

    assert response.status_code == 200
    assert time.perf_counter() - start >= 0.05


@pytest.mark.parametrize("body", [{"mode": "errors", "rate": 1.5}, {"mode": "explode"}, {}])
def test_invalid_fault_request_is_rejected(client, body):
    assert client.post("/admin/fault", json=body).status_code == 422


def test_json_log_line_has_fields_for_loki():
    formatter = JsonFormatter("sample-app")
    try:
        raise ValueError("boom")
    except ValueError:
        record = logging.LogRecord("sample_app", logging.ERROR, __file__, 1, "inventory call failed", None, sys.exc_info())
    record.route = ORDER_ROUTE

    line = json.loads(formatter.format(record))

    assert line["level"] == "error"
    assert line["service"] == "sample-app"
    assert line["msg"] == "inventory call failed"
    assert line["route"] == ORDER_ROUTE
    assert "ValueError: boom" in line["exc"]


def test_uvicorn_startup_lines_do_not_look_like_errors():
    record = logging.LogRecord("uvicorn.error", logging.INFO, __file__, 1, "Application startup complete.", None, None)

    line = JsonFormatter("sample-app").format(record)

    assert "error" not in line.lower()
