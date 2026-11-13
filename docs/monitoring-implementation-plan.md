# Monitoring and Playbook Execution: Implementation Plan

**Owner:** Keshan
**Branch:** `feature/monitoring`
**Status (13 Nov 2026):** steps 1 to 7 built and verified locally on Docker Desktop for Windows; step 8 blocked on other owners. Results per step below and in section 9.
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

### Layout (as built)

```text
monitoring/
├── docker-compose.yml          # sample-app, loadgen, prometheus, alertmanager, loki, promtail, executor
├── .env.example                # ports, bind address, versions; no secrets (.env is gitignored)
├── n8n-integration.env         # labels and queries for automation/.env (section 5)
├── prometheus/
│   ├── prometheus.yml
│   ├── rules/sample-app.rules.yml
│   └── tests/rules.test.yml    # promtool unit tests for the alerts
├── alertmanager/
│   ├── alertmanager.yml
│   └── secrets/                # n8n-token file, gitignored
├── loki/loki-config.yml
├── promtail/promtail-config.yml
├── sample-app/                 # Python service + load generator + Dockerfile + tests
├── scripts/                    # fault.sh, check_stack.py, create-n8n-token.sh, create-executor-secret.sh
└── README.md                   # how to run and verify
infrastructure/playbooks/executor/   # Python HTTP executor + tests
```

## 3. Decisions needed before or during build

These follow the `D-N8N-x` style. Each one goes into the `PLAN.md` decision log with date, who and why once agreed. Note: `PLAN.md` is not on this branch today.

| ID | Decision | Proposal | Why | Needs |
|---|---|---|---|---|
| D-MON-1 | Service label name, everywhere | `service` in Prometheus, Loki and alerts. Value `sample-app` | One label name means `LOKI_SERVICE_LABEL`, `PROM_SERVICE_LABEL` and `ALERT_SERVICE_LABEL` are all `service`. It matches `ALERT_SERVICE_LABEL` and `LOKI_SERVICE_LABEL` defaults already. The scrape `job` is also set to `sample-app` so the n8n default `job` still works | Tharindu, Vishwa |
| D-MON-2 | Sample app language | Python (FastAPI + `prometheus_client`), single worker | Python is the team's choice for backend services. `prometheus_client` on Linux exposes `process_cpu_seconds_total` and `process_resident_memory_bytes`, the names workflow 03 already defaults to. A single worker avoids multiprocess metric mode | Team note only |
| D-MON-3 | How n8n and the monitoring stack reach each other | **Tested 13 Nov:** `host.docker.internal` reaches ports published on `127.0.0.1` on Docker Desktop for Windows, in both directions (Alertmanager to n8n, n8n to Prometheus, Loki and the executor). No change to `automation/docker-compose.yml` needed. On a Linux host this is expected **not** to work (`host-gateway` is the bridge address, not loopback; not tested): use a shared external Docker network there | n8n is published on `127.0.0.1` only (N-5) | Vishwa (only for a Linux host) |
| D-MON-4 | Promtail or Grafana Alloy | Use Promtail as assigned, pinned to `3.6.11`. Docker Hub shows no Promtail release after `3.6.11` (May 2026) while Loki continues (`3.7.9`, Oct 2026), consistent with the announced move to Alloy. Plan a move to Alloy before any long-lived deployment | The task names Promtail; switching shippers changes no n8n contract as long as the `service` label stays | Owner |
| D-MON-5 | Error-rate threshold and alert timing | Fire when 5xx ratio > 5% over 5m, `for: 2m`. `PROM_THRESHOLD_ERROR_RATE=0.05` | Same value as `automation/test-data/sample-alert.json` ("Error rate above 5%"), so the demo and test data agree | Tharindu |
| D-MON-6 | Executor scope for the demo | Phase A: `restart` and `circuit_breaker` real. Phase B: `rollback` and `scale` real against the sample app only. Until Phase B is done, those 2 answer `422 unsupported` | Restart is the main demo path. Rollback and scale need extra sample-app setup (2 image tags, a replica container) | Owner |
| D-MON-7 | Executor nonce store | In-process store guarded by a lock, plus idempotency on `playbook_run_id` | The executor is one process, so a lock makes the nonce check atomic and avoids the KI-1 problem n8n has with static data | Vishwa (for the 06 side) |
| D-MON-8 | Executor secret | Its own `EXECUTOR_SIGNING_SECRET`, not `MACHINE_SIGNING_SECRET` | A leaked n8n/backend secret should not also allow container restarts. n8n reads it with `$env` like the other secret (D-N8N-1) | Vishwa |
| D-MON-9 | Window of the n8n error-rate query | `[2m]` for `PROM_QUERY_ERROR_RATE`; the alert keeps `[5m]` | Measured: after a real restart the 2m ratio was 0 after about 100 s, the 5m ratio still 0.2 after 3 minutes, so workflow 07 (3 checks, 60 s apart) answered `not_recovered` with 5m and `recovered` with 2m | Tharindu |

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
- **Status (13 Nov 2026):** done. 20 tests pass, 1 skipped (process metrics, Linux only). Live run on Windows: 50% error fault gave about 50% 5xx and `error` log lines; opening the breaker stopped the 5xx. Image builds and runs as uid 10001; process metrics present in the container. Fix found in step 3: uvicorn startup lines (logger `uvicorn.error`) matched the workflow 02 filter; now logged as `uvicorn`.

### Step 2: Prometheus (G2)

- `scrape_interval: 15s`, `evaluation_interval: 15s`.
- Job `sample-app`, static target `sample-app:8000`, static label `service: sample-app`. Also scrape Prometheus, Alertmanager and Loki themselves (useful to prove Alertmanager delivery, step 5).
- Published on `127.0.0.1:9090` only. Retention 7 days, local volume.
- **Verify:** `/api/v1/targets` shows `sample-app` `up`; every query in section 5 returns a value via `/api/v1/query`.
- **Status:** done. Prometheus `v3.15.1`. `scripts/check_stack.py`: 4 targets up, both rules loaded, every query in `n8n-integration.env` plus the 07 `up` query and the 03 CPU and memory defaults return a number.

### Step 3: Loki and Promtail (G3)

- Loki single-binary, filesystem storage, `127.0.0.1:3100`, auth disabled (local only; record this as local-only in the README).
- Promtail with `docker_sd_configs` on the Docker socket (read-only mount). Keep only containers with the label `logging=promtail`. Relabel `__meta_docker_container_label_com_docker_compose_service` to `service`, so the sample app's streams carry `service="sample-app"`. Add a JSON pipeline stage that extracts `level` as a label.
- **Verify:** `GET /loki/api/v1/query_range` with `{service="sample-app"}` returns lines; with a fault on, the workflow 02 query (section 5) returns error lines.
- **Status:** done. Loki `3.7.9`, Promtail `3.6.11`. Label `service` has `sample-app`; Loki also adds `service_name` and `detected_level` on its own. During the fault, workflow 02 (live, in n8n) returned `evidence_found` with 200 `inventory call failed` error lines. Note: `:ro` on the Promtail socket mount does not limit the Docker API.

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
- **Status:** done. Alertmanager `v0.34.2`. `amtool check-config` and `promtool check config` pass; `promtool test rules prometheus/tests/rules.test.yml` passes (10% errors fires with labels `service`, `severity` and the exact annotations; 4% does not; `ServiceDown` after 1 minute). The `HighErrorRate` alert carries `alertname`, `service`, `severity` only (`sum by (service)` drops `instance`); `ServiceDown` also carries `instance` and `job`. Routing was tested with real alerts in step 5 instead of a hand-made one.

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

**Status:** done, against a throwaway n8n `2.40.5` running the workflows from `origin/feature/n8n-incident-workflow` (imported with the n8n CLI, the same way `run-n8n-integration.mjs` does). Groq, GitHub and the backend pointed at a closed local port, so nothing left the machine.

| Check | Result |
|---|---|
| `HighErrorRate` | Fault 02:23:18, pending 02:24:31, firing 02:26:23, delivered 02:26:51 (about 3.5 minutes). Alertmanager `notifications_total{integration="webhook"}` 0 to 1, all failure reasons 0 |
| Workflow 01 | `success`; parsed `alert_name=HighErrorRate`, `service_name=sample-app`, `severity=critical`; then ran 05, which ran 02, 03 and 04 |
| Workflow 02 (live Loki) | `evidence_found`, 200 error lines |
| Workflow 03 (live Prometheus) | `evidence_found`: `error_rate` 0.35 abnormal; CPU, memory, p95 latency and request rate returned values. Baselines were `null` because the stack was younger than 30 minutes |
| Resolved | Delivered 02:36:51; workflow 01 answered 202 with `resolved_alerts: 1` |
| `ServiceDown` | Container stopped 02:38:19, firing 02:39:52, delivered 02:40:21, workflow 01 parsed `alert_name=ServiceDown` |
| Unauthenticated / wrong token, sent directly to n8n | 403 both |
| Alertmanager webhook failures over all tests | 0 |
| Not tested by me | A wrong token sent *by Alertmanager* (only direct requests were tested) and de-duplication of a repeated alert (covered by the n8n team's own tests) |

### Step 6: Labels and queries handoff (G6)

Send section 5 to Tharindu and Vishwa after every query in it has returned real data in step 2 and step 5. Then, with Tharindu, run workflows 02 and 03 against the live stack (normal vs faulty) as listed in `automation/team-workflows/tharindu/README.md`.

**Status:** values verified (section 5) and committed in `monitoring/n8n-integration.env`. Workflows 02, 03 and 07 already ran against the live stack (steps 5 and 7). Sending them to Tharindu and Vishwa is a message from Keshan; it is not something this repository can do.

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
| `restart` | Docker restart of the allowlisted container, stop grace 10 s, then wait until `/health` is 200 (timeout 60 s) | A |
| `circuit_breaker` | `POST /admin/circuit-breaker {open: true}` on the sample app, timeout 5 s, 3 attempts | A |
| `rollback` | Recreate the container from the previous allowlisted image tag (`sample-app:v1`); needs a `v2` tag with a known bug | B |
| `scale` | Start the pre-defined replica container `sample-app-2` (fixed max of 2) | B |

**Safety:**

- The allowlist (`service_name` to container name and allowed actions) is a config file in the repo, read at startup. Nothing else can be touched.
- The Docker socket gives root-level control of the host. Mitigations: the executor is published on `127.0.0.1:9095` only (n8n reaches it through `host.docker.internal`, D-MON-3), runs as non-root uid 10001 with socket access through group 0, and only gets and restarts the allowlisted container. Optional hardening, not done: a Docker socket proxy that allows only the restart call.
- Every request is logged: what was asked, what ran, result, duration. No signatures or secrets in logs.
- Every network call has a timeout and a retry limit.

**n8n side** (Vishwa): replace the 4 `Execute: <action>` Code nodes in workflow 06 with a signed HTTP Request to the executor, as the node comment already describes, and switch `REMEDIATION_EXECUTION_MODE` to a real mode. Keshan supplies the URL, the secret (out of band) and a working test request.

**Verify:**

- pytest: signature valid/invalid/expired, replayed nonce, extra field, non-allowlisted service, idempotent repeat of `playbook_run_id`, each action with the Docker client mocked.
- HMAC interop test against the n8n signing code.
- Live: signed `restart` against the running sample app, confirm the container restarted (`docker inspect` start time changed) and `/health` is back. Then `circuit_breaker` with a fault active, confirm error rate drops.
- Recovery check: after a real action, workflow 07 queries `up` and the error rate and returns `recovered`.

**Status:** Phase A done; Phase B (`rollback`, `scale`) not built and answers 422 (D-MON-6 open).

- pytest: 32 pass, including a signature vector produced by `automation/src/lib/hmac.js`.
- Live, signed by `signedBackendRequest()` from `hmac.js` inside the n8n container, over `host.docker.internal:9095`: `restart` 200 and the container really restarted (`StartedAt` changed, healthy after 2 s); same run re-signed 200 with `repeated: true` and no second restart; exact replay 409; forged signature 401; `rollback` 422; `circuit_breaker` 200 and the app reported `breaker_open: true`.
- Recovery: fault at 50% for 2.5 minutes, executor `restart`, then workflow 07 (live, via a harness workflow): `recovered`, `db_status: healthy` on the 2nd check (error rate 0.211, then 0). With the earlier 5m query it answered `not_recovered`; see D-MON-9. Storing the recovery check failed only because no backend was running.
- Not done: a socket proxy; 06 calling the executor (Vishwa's change).

### Step 8: Full remediation loop (with Vishwa, Tharindu, Vinuka)

Fault, alert, n8n 01, approval, backend trigger (BD-5), 06 calls executor, 07 verifies recovery. This depends on BD-5 (backend trigger) and BD-6 (`service_name` in `request_payload`), which are not built yet. Until then, 06 can be triggered with a signed test request as `npm run test:n8n` already does.

**Status: blocked, not run.** Every hop that exists has been tested on its own (steps 5 and 7). What is missing, by owner:

| Missing | Owner | What exactly |
|---|---|---|
| 06 calls the executor | Vishwa | Replace the 4 `Execute: <action>` Code nodes with one signed request: `signedBackendRequest({ MACHINE_SIGNING_SECRET: $env.EXECUTOR_SIGNING_SECRET, BACKEND_BASE_URL: $env.EXECUTOR_URL, BACKEND_TIMEOUT_MS: '90000' }, 'POST', '/v1/execute', { action, service_name, playbook_run_id })`, then an HTTP Request node with a 90 s timeout. 200 = success; 500 = failed (do not retry with the same run); 4xx = refused. Add `EXECUTOR_URL=http://host.docker.internal:9095` and `EXECUTOR_SIGNING_SECRET` to `automation/.env` and the compose file |
| Backend calls 06 after approval | Vinuka | BD-5 |
| `service_name` in the run's `request_payload` | Vinuka | BD-6 |
| Incident created from the alert | Backend + database team | BD-1 |

## 5. Service labels and queries for Tharindu and Vishwa

**Status: verified 13 Nov 2026** against the live stack and the n8n workflows (steps 5 and 7). Source of truth: `monitoring/n8n-integration.env`; `scripts/check_stack.py` tests exactly that file.

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
PROM_QUERY_ERROR_RATE=(sum(rate(http_requests_total{service="{{service}}",status=~"5.."}[2m])) or vector(0)) / sum(rate(http_requests_total{service="{{service}}"}[2m]))
PROM_QUERY_LATENCY_P95=histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{service="{{service}}"}[5m])))
PROM_QUERY_REQUEST_RATE=sum(rate(http_requests_total{service="{{service}}"}[5m]))
PROM_THRESHOLD_ERROR_RATE=0.05
PROM_THRESHOLD_LATENCY_P95=0.5
# PROM_QUERY_CPU / PROM_QUERY_MEMORY left empty: the workflow 03 defaults match prometheus_client's process metrics.

# Executor (06, once Vishwa wires it; D-MON-8)
EXECUTOR_URL=http://host.docker.internal:9095
EXECUTOR_SIGNING_SECRET=<same value as monitoring/.env, shared out of band>
```

Notes for the workflow owners:

- Service name for testing: `sample-app`.
- `or vector(0)` keeps the error-rate query returning `0` instead of no data when there are no 5xx responses, so workflow 07 can say `recovered` instead of `unable_to_verify`.
- Workflow 07's `up` query becomes `min(up{service="sample-app"})`, which works because the scrape job adds the `service` label.
- Workflow 02 query becomes `{service="sample-app"} |~ "(?i)(error|exception|fatal|panic|critical|warn)"`.
- The error-rate query uses a 2m window so workflow 07 can see a recovery within its 3 checks (D-MON-9).
- Alert payload labels: `HighErrorRate` has `alertname`, `service`, `severity=critical`; `ServiceDown` also has `instance` and `job`. Annotations `summary` and `description`.
- On a Linux host (D-MON-3), use a shared Docker network; the URLs become `http://prometheus:9090`, `http://loki:3100` and `http://executor:9095`.

## 6. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| `host.docker.internal` to `127.0.0.1` ports does not work on a Linux host (D-MON-3) | No alert reaches n8n there | Works on Docker Desktop (tested); use a shared network on Linux |
| No traffic, so ratio queries return no data | 03 shows nothing, 07 says `unable_to_verify` | Load generator always on; `or vector(0)` |
| Docker socket in Promtail and the executor | Host-level access if either is compromised | Local only; executor non-root, allowlist, `127.0.0.1` only, HMAC; optional socket proxy |
| Executor forgets nonces and run results when it restarts | A replay within 5 minutes after an executor restart would pass the nonce check | Database run state allows a run to start once; restart of the executor is rare |
| BD-1, BD-5, BD-6 not built | End-to-end loop stops at alert intake or needs a hand-signed trigger | Report this honestly in the readiness report; test each hop separately |
| Promtail support status (D-MON-4) | Possible future migration | Pin the version; label contract does not depend on the shipper |
| Image versions | Unpinned images can change under us | Pin exact versions in `monitoring/.env.example` |

## 7. Out of scope

Grafana dashboards, hosted or shared deployment, HTTPS reverse proxy for n8n, the backend trigger (BD-5) and incident creation (BD-1). Any of these can be added if the owner asks.

## 8. Dependencies and cost

Docker images for Prometheus, Alertmanager, Loki and Promtail; Python packages `fastapi`, `uvicorn`, `prometheus_client`, `docker`, `pytest`, `httpx`. All are free and open source. No paid service, API or trial is needed. If that changes, get approval before adding it.

## 9. Readiness report to the owner (13 Nov 2026)

All results are from a local Docker Desktop (Windows) run, not a shared or hosted environment.

| Item | Status | Evidence |
|---|---|---|
| Prometheus setup | ready | 4 targets up, rules loaded, all handed-off queries return values (step 2) |
| Loki and Promtail setup | ready | `service="sample-app"` streams; workflow 02 found 200 real error lines (step 3, 5) |
| Service labels and queries | verified, in `monitoring/n8n-integration.env` | Section 5; still to be sent to Tharindu and Vishwa |
| Alertmanager config and availability | ready | Config and rule tests pass; 3 notifications (firing, resolved, ServiceDown) delivered, 0 failures (step 4, 5) |
| Alert reaches n8n | yes | Workflow 01 accepted real `HighErrorRate`, resolved and `ServiceDown` alerts (step 5) |
| Playbook executor: restart, circuit_breaker | ready | Live signed calls from the n8n container; real restart; recovery confirmed by workflow 07 (step 7) |
| Playbook executor: rollback, scale | not built | 422 until D-MON-6 is decided |
| Executor integration endpoint | `POST http://host.docker.internal:9095/v1/execute`, HMAC with `EXECUTOR_SIGNING_SECRET` | `infrastructure/playbooks/executor/README.md` |
| Ready for real-service testing | **monitoring: yes. Remediation loop: no** | The loop needs 06 wired to the executor (Vishwa), BD-5 and BD-6 (Vinuka) and BD-1 (backend + database), step 8 |
