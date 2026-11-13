# Monitoring and Playbook Execution: Implementation Plan

**Owner:** Keshan
**Branch:** `feature/monitoring`
**Status:** plan only (13 Nov 2026). Nothing below is built or verified yet.
**Consumers:** Tharindu (workflows 02, 03, 07), Vishwa (workflows 01, 06), Vinuka (backend trigger BD-5, BD-6).

The contracts this plan targets were read from the code on `origin/feature/n8n-incident-workflow`:
`automation/src/nodes/01-alert-intake/parse-alerts.js`, `02-log-analysis/build-query.js`, `03-metrics-analysis/build-queries.js`, `07-recovery-check/plan.js`, `06-remediation/execute-action.js`, `automation/.env.example` and `docs/automation-integration-requirements.md` sections 3, 4 and 7.

---

## 1. Goals

| # | Assigned task | Done when |
|---|---|---|
| G1 | Sample application with Prometheus metrics | `/metrics` exposes request count, duration and process metrics; a fault can be switched on and off. The `service` label is added by Prometheus at scrape time (step 2) |
| G2 | Prometheus collects application metrics | Target `sample-app` is `up=1`; the agreed PromQL queries return data |
| G3 | Loki and Promtail collect application logs | `{service="sample-app"}` returns the app's log lines in Loki |
| G4 | Alertmanager detects high error rate and sends to n8n | `HighErrorRate` fires and Alertmanager delivers it to `POST /webhook/alertmanager` with no notify errors |
| G5 | Failure reaches n8n end to end | A real injected fault produces a workflow 01 execution in n8n that accepts the alert (HTTP 2xx) |
| G6 | Labels and queries shared | Section 5 confirmed against the running stack and sent to Tharindu and Vishwa |
| G7 | Playbook executor ready | Executor accepts HMAC-signed requests for the 4 fixed actions and has been exercised against the sample app |
| G8 | Readiness report to the owner | Section 9 filled in with real results |

## 2. Target architecture

```text
            load generator ──HTTP──▶ sample-app (Python) ──stdout logs──▶ Docker
                                        │  /metrics                         │
                                        ▼                                   ▼
                                   Prometheus ◀─── rules            Promtail (docker_sd)
                                        │  alerts                           │
                                        ▼                                   ▼
                                  Alertmanager                            Loki
                                        │ webhook (Bearer token)            ▲
                                        ▼                                   │ LogQL (02)
                                       n8n ──── PromQL (03, 07) ──▶ Prometheus
                                        │
                                        │ 06: signed HTTP (HMAC)
                                        ▼
                                 Playbook executor ──Docker API──▶ sample-app container
```

All monitoring services run in one compose project in `monitoring/`. n8n stays in `automation/docker-compose.yml` (Vishwa's). The executor lives in `infrastructure/playbooks/`, the path the n8n docs already reference.

### Proposed layout

```text
monitoring/
├── docker-compose.yml          # prometheus, alertmanager, loki, promtail, sample-app, loadgen
├── .env.example                # ports, bind address, versions; no secrets
├── prometheus/
│   ├── prometheus.yml
│   └── rules/sample-app.rules.yml
├── alertmanager/
│   ├── alertmanager.yml
│   └── secrets/                # n8n-token file, gitignored
├── loki/loki-config.yml
├── promtail/promtail-config.yml
├── sample-app/                 # Python service + Dockerfile + tests
├── scripts/                    # inject-fault, clear-fault, check-stack
└── README.md                   # how to run; labels and queries (section 5)
infrastructure/playbooks/executor/   # Python HTTP executor + tests
```

## 3. Decisions needed before or during build

These follow the `D-N8N-x` style. Each one goes into the `PLAN.md` decision log with date, who and why once agreed. Note: `PLAN.md` is not on this branch today.

| ID | Decision | Proposal | Why | Needs |
|---|---|---|---|---|
| D-MON-1 | Service label name, everywhere | `service` in Prometheus, Loki and alerts. Value `sample-app` | One label name means `LOKI_SERVICE_LABEL`, `PROM_SERVICE_LABEL` and `ALERT_SERVICE_LABEL` are all `service`. It matches `ALERT_SERVICE_LABEL` and `LOKI_SERVICE_LABEL` defaults already. The scrape `job` is also set to `sample-app` so the n8n default `job` still works | Tharindu, Vishwa |
| D-MON-2 | Sample app language | Python (FastAPI + `prometheus_client`), single worker | Dynarq rule: Python for backend services. `prometheus_client` on Linux exposes `process_cpu_seconds_total` and `process_resident_memory_bytes`, the names workflow 03 already defaults to. A single worker avoids multiprocess metric mode | Team note only |
| D-MON-3 | How n8n and the monitoring stack reach each other | First test `host.docker.internal` (what `.env.example` assumes). If Alertmanager cannot reach n8n on `127.0.0.1:5678` that way, add a shared external Docker network `devops-net` to both compose files and use `http://n8n:5678` | n8n is published on `127.0.0.1` only (N-5). Whether a container can reach a loopback-bound host port through `host.docker.internal` on Docker Desktop for Windows is **not verified** | Vishwa (small change to `automation/docker-compose.yml` if needed) |
| D-MON-4 | Promtail or Grafana Alloy | Use Promtail as assigned, version pinned. Record that Grafana announced Promtail's deprecation in favour of Alloy (**to verify the current support status before build**) | The task names Promtail; switching shippers changes no n8n contract as long as the `service` label stays | Founder / owner |
| D-MON-5 | Error-rate threshold and alert timing | Fire when 5xx ratio > 5% over 5m, `for: 2m`. `PROM_THRESHOLD_ERROR_RATE=0.05` | Same value as `automation/test-data/sample-alert.json` ("Error rate above 5%"), so the demo and test data agree | Tharindu |
| D-MON-6 | Executor scope for the demo | Phase A: `restart` and `circuit_breaker` real. Phase B: `rollback` and `scale` real against the sample app only. Until Phase B is done, those 2 answer `422 unsupported` | Restart is the main demo path. Rollback and scale need extra sample-app setup (2 image tags, a replica container) | Owner |
| D-MON-7 | Executor nonce store | In-process store guarded by a lock, plus idempotency on `playbook_run_id` | The executor is one process, so a lock makes the nonce check atomic and avoids the KI-1 problem n8n has with static data | Vishwa (for the 06 side) |

## 4. Work plan

Order is by dependency. Each step lists how it is verified; nothing is reported as done without that check.

### Step 1: Sample application (G1)

- FastAPI service `sample-app`, endpoints:
  - `GET /api/orders`, `GET /api/orders/{id}`: normal traffic, small random latency.
  - `GET /health`: liveness.
  - `GET /metrics`: Prometheus exposition.
  - `POST /admin/fault` `{ "mode": "errors"|"latency"|"off", "rate": 0.0-1.0 }`: fault injection.
  - `POST /admin/circuit-breaker` `{ "open": true|false }`: used by the executor's `circuit_breaker` action (open = shed the failing dependency and return a degraded 200).
  - Admin endpoints are reachable only inside the Docker network (not published to the host).
- Metrics:
  - `http_requests_total{method, route, status}` (counter). The `route` label uses the route template, not the raw path, so cardinality stays fixed. Unknown paths use `route="unmatched"`. `/metrics` itself is not counted.
  - `http_request_duration_seconds{method, route}` (histogram, default buckets).
  - Default process and platform collectors (process metrics exist on Linux only, so inside the container).
  - Counters for status `500` are created at 0 at startup so the 5xx series always exists.
  - No `service` label from the app: Prometheus adds it as a target label, which also puts it on `up`. If the app exported one too, Prometheus would rename the app's copy to `exported_service`.
- Logs: one JSON line per request and per error to stdout (`ts`, `level`, `service`, `route`, `status`, `duration_ms`, `msg`). Errors log `level=error` with an exception line, so workflow 02's filter `(?i)(error|exception|fatal|panic|critical|warn)` finds them. No request bodies, tokens or user data in logs.
- Load generator: same image, command `python -m loadgen.loadgen`, calling the API about 5 times per second, with a timeout per request and no retries. Needed because without traffic the error-rate query has no data and workflow 07 answers `unable_to_verify`.
- **Verify:** pytest for the fault switch and metric names; `curl` `/metrics` and confirm the series above.
- **Status (13 Nov 2026):** built in `monitoring/sample-app/`. 19 tests pass, 1 skipped (process metrics, Linux only). Live run on Windows with the load generator: 50% error fault gave about 50% 5xx and `error` log lines with the traceback; opening the breaker stopped the 5xx. **Not yet verified:** the Docker image build (Docker daemon was not running) and the process metrics inside the container.

### Step 2: Prometheus (G2)

- `scrape_interval: 15s`, `evaluation_interval: 15s`.
- Job `sample-app`, static target `sample-app:8000`, static label `service: sample-app`. Also scrape Prometheus, Alertmanager and Loki themselves (useful to prove Alertmanager delivery, step 5).
- Published on `127.0.0.1:9090` only. Retention 7 days, local volume.
- **Verify:** `/api/v1/targets` shows `sample-app` `up`; every query in section 5 returns a value via `/api/v1/query`.

### Step 3: Loki and Promtail (G3)

- Loki single-binary, filesystem storage, `127.0.0.1:3100`, auth disabled (local only; record this as local-only in the README).
- Promtail with `docker_sd_configs` on the Docker socket (read-only mount). Keep only containers with the label `logging=promtail`. Relabel `__meta_docker_container_label_com_docker_compose_service` to `service`, so the sample app's streams carry `service="sample-app"`. Add a JSON pipeline stage that extracts `level` as a label.
- **Verify:** `GET /loki/api/v1/query_range` with `{service="sample-app"}` returns lines; with a fault on, the workflow 02 query (section 5) returns error lines.

### Step 4: Alert rules and Alertmanager (G4)

`prometheus/rules/sample-app.rules.yml`:

```yaml
groups:
  - name: sample-app
    rules:
      - alert: HighErrorRate
        expr: |
          sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
            / sum by (service) (rate(http_requests_total[5m])) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Error rate above 5% on {{ $labels.service }}"
          description: "5xx responses are {{ $value | humanizePercentage }} of requests over 5 minutes."
      - alert: ServiceDown
        expr: up{service!=""} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.service }} is down"
          description: "Prometheus cannot scrape {{ $labels.instance }}."
```

`alertmanager/alertmanager.yml` (receiver shape taken from `docs/automation-integration-requirements.md` section 4):

```yaml
route:
  receiver: n8n-alert-intake
  group_by: [alertname, service]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
receivers:
  - name: n8n-alert-intake
    webhook_configs:
      - url: http://host.docker.internal:5678/webhook/alertmanager   # or http://n8n:5678/... per D-MON-3
        send_resolved: true
        max_alerts: 50            # workflow 01 rejects more than 50
        http_config:
          authorization:
            type: Bearer
            credentials_file: /etc/alertmanager/secrets/n8n-token
```

- The token file holds the same random value Vishwa stores in the n8n credential "Alertmanager Webhook Token". It is created locally, gitignored, and never pasted into chat or the repo. `.env.example` and the README explain how to create it.
- Every label the alert sends is checked against `parse-alerts.js`: `alertname` present, `service` matches `^[A-Za-z0-9_.:-]{1,100}$`, `severity=critical` maps to incident severity `critical`, `startsAt` valid.
- Alertmanager published on `127.0.0.1:9093`.
- **Verify:** `amtool check-config` and `promtool check rules` pass; send `automation/test-data/sample-alert.json` style alert through Alertmanager's API to confirm routing before using a real fault.

### Step 5: End-to-end failure test (G5)

Run with n8n from `automation/` and workflow 01 active.

1. Baseline: traffic running for at least 10 minutes, no alerts firing.
2. `scripts/inject-fault` sets `errors` at rate 0.5.
3. Watch: alert `pending` then `firing` in Prometheus (about 2 to 3 minutes), then Alertmanager sends after `group_wait`.
4. Evidence to capture:
   - Prometheus `/api/v1/alerts` showing `HighErrorRate` firing with `service="sample-app"`.
   - Alertmanager metrics `alertmanager_notifications_total{integration="webhook"}` increased and `alertmanager_notifications_failed_total{integration="webhook"}` unchanged; no notify errors in its log.
   - n8n execution of workflow 01 with HTTP 2xx and the parsed alert (`service_name=sample-app`, `severity=critical`).
5. `scripts/clear-fault`; confirm the `resolved` notification is accepted by workflow 01 (it acknowledges resolved alerts without creating incidents).
6. Repeat with `ServiceDown` by stopping the container.
7. Negative checks: wrong token gives 401/403 in n8n and a failed notification in Alertmanager; firing twice within `DEDUP_WINDOW_MINUTES` is de-duplicated by workflow 01.

Known limit, to state in the report: workflow 01 cannot create an incident yet (BD-1 is blocked on the backend and database). "Reaches n8n" in this step means workflow 01 receives and accepts the alert, not that an incident row exists.

### Step 6: Labels and queries handoff (G6)

Send section 5 to Tharindu and Vishwa after every query in it has returned real data in step 2 and step 5. Then, with Tharindu, run workflows 02 and 03 against the live stack (normal vs faulty) as listed in `automation/team-workflows/tharindu/README.md`.

### Step 7: Playbook executor (G7)

Location: `infrastructure/playbooks/executor/`, Python.

**Contract** (from `docs/automation-integration-requirements.md` section 3 and the comment in `execute-action.js`):

- `POST /v1/execute`, `Content-Type: application/json`.
- Body, exactly these fields (any other field gives 400): `{ "action": "restart"|"rollback"|"scale"|"circuit_breaker", "service_name": string, "playbook_run_id": uuid }`.
- Auth: same HMAC scheme as the rest of the project. `X-DC-Timestamp`, `X-DC-Nonce`, `X-DC-Signature: sha256=<hex>` over `timestamp.nonce.POST.path.rawBody`, ±300 s clock window, nonce 16 to 200 chars `[A-Za-z0-9_-]`, secret of at least 32 chars from the environment (`EXECUTOR_SIGNING_SECRET`). Interop-tested against `automation/src/lib/hmac.js` and the backend's `buildSignedHeaders()`.
- Responses:

| HTTP | When |
|---|---|
| 200 | Action ran; body `{ executed: true, action, service_name, playbook_run_id, started_at, finished_at, detail }` |
| 200 | Same `playbook_run_id` seen before: returns the stored result, does **not** run again (safe for n8n retries) |
| 400 | Invalid JSON, missing or extra fields, bad uuid |
| 401 | Missing or bad signature, timestamp outside window, bad nonce format |
| 403 | `service_name` not in the allowlist |
| 409 | Nonce already used |
| 422 | Action not supported for this service (Phase B actions before they exist) |
| 500 | Action failed; body has a short reason, no stack trace |
| 503 | Secret missing or too short |

**What each action does** (fixed in code, never taken from the request or the AI):

| Action | Effect on `sample-app` | Phase |
|---|---|---|
| `restart` | Docker restart of the allowlisted container, timeout 30 s, then wait until `/health` is 200 (timeout 60 s) | A |
| `circuit_breaker` | `POST /admin/circuit-breaker {open: true}` on the sample app, timeout 5 s, 2 retries | A |
| `rollback` | Recreate the container from the previous allowlisted image tag (`sample-app:v1`); needs a `v2` tag with a known bug | B |
| `scale` | Start the pre-defined replica container `sample-app-2` (fixed max of 2) | B |

**Safety:**

- The allowlist (`service_name` to container name and allowed actions) is a config file in the repo, read at startup. Nothing else can be touched.
- The Docker socket gives root-level control of the host. Mitigations: the executor is not published to the host (internal network only, reachable by n8n), runs as a non-root user where the socket permissions allow it, and only calls the 3 Docker operations it needs. Optional hardening: put a Docker socket proxy in front that allows only container restart, start and inspect (free, open source; decide during build).
- Every request is logged: what was asked, what ran, result, duration. No signatures or secrets in logs.
- Every network call has a timeout and a retry limit (Dynarq rule 6).

**n8n side** (Vishwa): replace the 4 `Execute: <action>` Code nodes in workflow 06 with a signed HTTP Request to the executor, as the node comment already describes, and switch `REMEDIATION_EXECUTION_MODE` to a real mode. Keshan supplies the URL, the secret (out of band) and a working test request.

**Verify:**

- pytest: signature valid/invalid/expired, replayed nonce, extra field, non-allowlisted service, idempotent repeat of `playbook_run_id`, each action with the Docker client mocked.
- HMAC interop test against the n8n signing code.
- Live: signed `restart` against the running sample app, confirm the container restarted (`docker inspect` start time changed) and `/health` is back. Then `circuit_breaker` with a fault active, confirm error rate drops.
- Recovery check: after a real action, workflow 07 queries `up` and the error rate and returns `recovered`.

### Step 8: Full remediation loop (with Vishwa, Tharindu, Vinuka)

Fault, alert, n8n 01, approval, backend trigger (BD-5), 06 calls executor, 07 verifies recovery. This depends on BD-5 (backend trigger) and BD-6 (`service_name` in `request_payload`), which are not built yet. Until then, 06 can be triggered with a signed test request as `npm run test:n8n` already does.

## 5. Service labels and queries for Tharindu and Vishwa

**Status: proposed, not yet verified against a running Prometheus or Loki.** They will be re-sent marked "verified" after step 5.

`automation/.env` values:

```dotenv
# Alert intake (01)
ALERT_SERVICE_LABEL=service

# Loki (02)
LOKI_URL=http://host.docker.internal:3100
LOKI_SERVICE_LABEL=service

# Prometheus (03, 07)
PROMETHEUS_URL=http://host.docker.internal:9090
PROM_SERVICE_LABEL=service
PROM_QUERY_ERROR_RATE=(sum(rate(http_requests_total{service="{{service}}",status=~"5.."}[5m])) or vector(0)) / sum(rate(http_requests_total{service="{{service}}"}[5m]))
PROM_QUERY_LATENCY_P95=histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{service="{{service}}"}[5m])))
PROM_QUERY_REQUEST_RATE=sum(rate(http_requests_total{service="{{service}}"}[5m]))
PROM_THRESHOLD_ERROR_RATE=0.05
PROM_THRESHOLD_LATENCY_P95=0.5
# PROM_QUERY_CPU / PROM_QUERY_MEMORY left empty: the workflow 03 defaults match prometheus_client's process metrics.
```

Notes for the workflow owners:

- Service name for testing: `sample-app`.
- `or vector(0)` keeps the error-rate query returning `0` instead of no data when there are no 5xx responses, so workflow 07 can say `recovered` instead of `unable_to_verify`.
- Workflow 07's `up` query becomes `min(up{service="sample-app"})`, which works because the scrape job adds the `service` label.
- Workflow 02 query becomes `{service="sample-app"} |~ "(?i)(error|exception|fatal|panic|critical|warn)"`.
- Alert payload labels: `alertname` (`HighErrorRate` or `ServiceDown`), `service`, `severity=critical`, `instance`; annotations `summary` and `description`.
- If D-MON-3 moves to a shared network, the URLs become `http://prometheus:9090` and `http://loki:3100`.

## 6. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| Alertmanager cannot reach n8n on `127.0.0.1` (D-MON-3) | No alert reaches n8n | Test first in step 4; fallback is the shared network |
| No traffic, so ratio queries return no data | 03 shows nothing, 07 says `unable_to_verify` | Load generator always on; `or vector(0)` |
| Docker socket in Promtail and the executor | Host-level access if either is compromised | Local only, read-only mount for Promtail, allowlist and no published port for the executor, optional socket proxy |
| BD-1, BD-5, BD-6 not built | End-to-end loop stops at alert intake or needs a hand-signed trigger | Report this honestly in the readiness report; test each hop separately |
| Promtail support status (D-MON-4) | Possible future migration | Pin the version; label contract does not depend on the shipper |
| Image versions | Unpinned images can change under us | Pin exact versions in `monitoring/.env.example` |

## 7. Out of scope

Grafana dashboards, hosted or shared deployment, HTTPS reverse proxy for n8n, the backend trigger (BD-5) and incident creation (BD-1). Any of these can be added if the owner asks.

## 8. Dependencies and cost

Docker images for Prometheus, Alertmanager, Loki and Promtail; Python packages `fastapi`, `uvicorn`, `prometheus_client`, `docker`, `pytest`, `httpx`. All are free and open source. No paid service, API or trial is needed. If that changes, ask the founder first (Dynarq rule 8).

## 9. Readiness report to the owner (fill in with real results)

| Item | Status | Evidence |
|---|---|---|
| Prometheus setup | not started | |
| Loki and Promtail setup | not started | |
| Service labels and queries shared | proposed (section 5), not verified | |
| Alertmanager config and availability | not started | |
| Alert reaches n8n (workflow 01 accepts) | not tested | |
| Playbook executor: restart, circuit_breaker | not started | |
| Playbook executor: rollback, scale | not started | |
| Executor integration endpoint | proposed: `POST /v1/execute` on the internal network | |
| Ready for real-service testing | **no** | Depends on the rows above, plus BD-1, BD-5 and BD-6 on the backend side |
