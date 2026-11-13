# Monitoring and Observability

Metrics, logs and alerts for incident investigation, plus the sample service the incident workflows are tested against. Plan, decisions (D-MON-x) and test results: `docs/monitoring-implementation-plan.md`.

| Service | Port (host) | Purpose |
|---|---|---|
| `sample-app` | not published | Orders API with metrics, JSON logs and switchable faults (`sample-app/README.md`) |
| `loadgen` | none | About 5 requests per second to `sample-app`, so rate queries always have data |
| `prometheus` | `127.0.0.1:9090` | Scrapes every target and adds the `service` label; evaluates the alert rules |
| `alertmanager` | `127.0.0.1:9093` | Sends alerts to n8n workflow 01 (`/webhook/alertmanager`, Bearer token) |
| `loki` | `127.0.0.1:3100` | Log store |
| `promtail` | none | Ships logs of containers labelled `logging=promtail`, with the `service` label |
| `executor` | `127.0.0.1:9095` | Playbook executor for n8n workflow 06 (`infrastructure/playbooks/executor/README.md`) |

All ports are bound to `127.0.0.1` (local development only). Loki has no authentication and the sample app's admin API has none: do not publish them.

## Start

Needs Docker with Compose. From `monitoring/`:

```bash
scripts/create-n8n-token.sh          # alertmanager/secrets/n8n-token (gitignored)
scripts/create-executor-secret.sh    # EXECUTOR_SIGNING_SECRET in .env (gitignored)
docker compose up -d --build
python scripts/check_stack.py        # PASS/FAIL per check; wait 1 to 2 minutes after start
```

Then, in n8n (`automation/`):

1. Copy `n8n-integration.env` into `automation/.env`.
2. Set the n8n credential **Alertmanager Webhook Token** to `Bearer <content of alertmanager/secrets/n8n-token>`.
3. Make sure workflow 01 is active. n8n must be running on `127.0.0.1:5678`.

## Labels and queries for the n8n workflows

`n8n-integration.env` holds the values; `check_stack.py` runs every query in it. Summary:

| Setting | Value |
|---|---|
| Service label, everywhere | `service` (`ALERT_SERVICE_LABEL`, `LOKI_SERVICE_LABEL`, `PROM_SERVICE_LABEL`) |
| Service name for testing | `sample-app` |
| Error rate (03, 07) | 5xx share of requests over **2m**, threshold `0.05` |
| Latency p95 (03) | from `http_request_duration_seconds_bucket`, threshold `0.5` s |
| Request rate (03) | `sum(rate(http_requests_total{service=...}[5m]))` |
| CPU and memory (03) | workflow 03 defaults work as they are |
| Recovery `up` (07) | `min(up{service="sample-app"})` |
| Alert labels | `alertname` (`HighErrorRate`, `ServiceDown`), `service`, `severity=critical` |

## Alerts

| Alert | Fires when | Typical time to n8n |
|---|---|---|
| `HighErrorRate` | 5xx share over 5m above 5% for 2 minutes | About 3.5 minutes after a 50% fault starts |
| `ServiceDown` | Prometheus cannot scrape a target for 1 minute | About 2 minutes |

Resolved notifications are sent too (`send_resolved: true`). Rule unit tests:

```bash
docker run --rm --entrypoint promtool -v "$PWD/prometheus:/etc/prometheus:ro" \
  prom/prometheus:v3.15.1 test rules /etc/prometheus/tests/rules.test.yml
```

## Break and fix the sample app

```bash
scripts/fault.sh errors 0.5      # half of the requests fail
scripts/fault.sh latency 1       # every request is slow
scripts/fault.sh breaker open    # stop calling the failing dependency
scripts/fault.sh off             # clear the fault (a restart also clears it)
scripts/fault.sh status
docker stop dc-sample-app        # for ServiceDown; docker start dc-sample-app
```

## Status

Built and verified locally on 13 Nov 2026 (Docker Desktop for Windows): real alerts reached n8n workflow 01; workflows 02, 03 and 07 ran against this stack; the executor restarted the sample app from a signed n8n request and workflow 07 confirmed recovery. Not done: running on Linux (see D-MON-3), Grafana dashboards, the full remediation loop (blocked on BD-1, BD-5, BD-6 and wiring 06 to the executor).
