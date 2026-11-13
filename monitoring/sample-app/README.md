# sample-app

Small orders API used as the target of the monitoring stack and the playbook executor. See `docs/monitoring-implementation-plan.md`, step 1.

## Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /api/orders`, `GET /api/orders/{order_id}` | Normal traffic. Each call uses a simulated "inventory" dependency |
| `GET /health` | Liveness, not affected by faults |
| `GET /metrics` | Prometheus exposition |
| `GET /admin/fault` | Current fault state |
| `POST /admin/fault` `{"mode": "errors"\|"latency"\|"off", "rate": 0.0-1.0}` | Make the dependency fail or stall for that share of requests |
| `POST /admin/circuit-breaker` `{"open": true\|false}` | Open = stop calling the dependency and return a degraded 200 |

The admin endpoints have no authentication. **Do not publish the container port to the host**; only services on the Docker network should reach it. A restart clears the fault and the breaker (state is in memory).

## Metrics

- `http_requests_total{method, route, status}`
- `http_request_duration_seconds{method, route}` (histogram)
- Process metrics (`process_cpu_seconds_total`, `process_resident_memory_bytes`, Linux only)

`route` is the route template (`/api/orders/{order_id}`), or `unmatched`. The app does not export a `service` label; Prometheus adds it at scrape time.

## Logs

One JSON object per line on stdout: `ts`, `level`, `service`, `logger`, `msg`, plus `method`, `route`, `status`, `duration_ms` on access lines and `exc` on errors.

## Configuration

| Variable | Default | |
|---|---|---|
| `SERVICE_NAME` | `sample-app` | Written into log lines |
| `HOST` | `127.0.0.1` (`0.0.0.0` in the image) | |
| `PORT` | `8000` | |
| `LOG_LEVEL` | `INFO` | |
| `FAULT_LATENCY_SECONDS` | `1.5` | Delay added by the `latency` fault |

Load generator (`python -m loadgen.loadgen`, same image): `TARGET_URL` (`http://sample-app:8000`), `LOADGEN_RPS` (5), `REQUEST_TIMEOUT_SECONDS` (2), `REPORT_EVERY_SECONDS` (30). Requests are never retried.

## Run and test locally

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements-dev.txt   # .venv/bin/python on Linux/macOS
.venv/Scripts/python -m pytest
PORT=8099 .venv/Scripts/python -m app
```

Run one uvicorn worker only: `prometheus_client` keeps metrics per process.
