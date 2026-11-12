# Automation – Integration Requirements and Blockers

What the n8n workflows need from other parts of the project, what is missing today, and which decisions are open.
Everything here was checked against the code on branch `feature/n8n-incident-workflow` (8 Nov 2026; updated 10 Nov 2026 for BD-3, N-1, N-2, N-3 and N-5).

## 1. Verified backend contract (what exists today)

| Item | Status | Where |
|---|---|---|
| HMAC scheme `timestamp.nonce.METHOD.path.rawBody`, headers `X-DC-Timestamp`, `X-DC-Nonce`, `X-DC-Signature: sha256=<hex>` | ✅ Implemented and verified. `automation/tests/hmac-interop.mjs` runs the backend's real middleware against the n8n code, in both directions. | `backend/src/middleware/machine-auth.ts` |
| Clock window 300 s, nonce 16–200 chars `[A-Za-z0-9_-]`, replay → 409, secret ≥ 32 chars | ✅ Implemented | same |
| Signed path = `req.originalUrl`, so n8n signs the full path, e.g. `/api/machine/playbook-runs/<id>/start` | ✅ Implemented | `machine.routes.ts` |
| `POST /api/machine/playbook-runs/:id/start` `{ n8n_execution_id, workflow_name }` → `start_playbook_run` (needs an **approved** run, an enabled playbook and an approved approval) | ✅ Implemented; used by workflow 06 | `machine.routes.ts`, migration `…000700` |
| `POST /api/machine/playbook-runs/:id/complete` `{ n8n_execution_id, status: success\|failed, result }` → `complete_playbook_run` | ✅ Implemented; used by workflow 06. **N-1:** 06 retries timeouts, connection errors and 5xx (max 3 attempts, 2 s / 4 s, every attempt signed again with a new nonce), never 4xx. The function refuses a run that is not `running` (DC409), so a retry can't complete a run twice; a 409 with the status 06 sent, after an ambiguous attempt, counts as completed. | same, `automation/src/nodes/06-remediation/check-complete.js` |
| `POST /api/machine/recovery-checks` `{ incident_id, playbook_run_id, status: pending\|healthy\|unhealthy\|failed, check_type?, details? }` → `record_recovery_check` → `201 { data: { recovery_check_id } }` | ✅ **Implemented (BD-3, 10 Nov)**; used by workflow 07. Unknown incident → 404 (DC404); a run that does not exist or belongs to another incident → 400 (DC422, the database does not tell the two apart); unexpected error → 500 with a generic message. Tested with Vitest (`backend/tests/machine-recovery-checks.test.ts`) and with workflow 07's real request against the real route (`automation/tests/recovery-check-interop.mjs`). | `machine.routes.ts`, `services/recovery-check.service.ts` |
| Playbook action types | ✅ `restart`, `rollback`, `scale`, `circuit_breaker` (database CHECK `playbooks_action_type_allowed`) | baseline migration |

> **Conflict resolved by following the code.** The task description named the actions `restart_service`, `rollback_deployment`, `scale_service` and `circuit_breaker`. The database only allows `restart`, `rollback`, `scale` and `circuit_breaker`, so the workflows use those four.

## 2. Backend dependencies (missing, so the workflows report "blocked")

None of these URLs is invented in the workflows. BD-2 uses the **path already written in the approved contract** (`database/API_AND_INTEGRATION_CONTRACTS.md` B.3). Until the backend adds that route, the call gets 404 and the result says `not_implemented` (silent: no error notification). BD-3 is implemented (section 1): a 404 from the recovery-check route is a real error now and is reported.

| ID | Needed by | What is missing | Contract status | Suggested owner |
|---|---|---|---|---|
| **BD-1** | 01 Alert Intake | A machine endpoint that **creates an incident** (and returns `incident_id`) from an alert, idempotent on the alert fingerprint | ❌ Not in the contract. Needs a contract update first, **and a migration**: `incidents` has no fingerprint column, and no automation function creates incidents. When it exists, set `incident_status` to `created`/`failed` in 01 (N-3 then releases failed alerts for a retry). | Vishwa + Vinuka + database team |
| **BD-2** | 05 Root Cause | `POST /api/machine/investigations/:id/analysis` → `record_ai_analysis`, **plus** a way to create the investigation (no machine endpoint creates investigations) | Path is in the contract; the route is not implemented. Investigation creation is not in the contract. Checked: `record_ai_analysis` **accepts a NULL investigation id**, so an incident-level route (e.g. `/api/machine/incidents/:id/analysis`) would work without investigations; that is a contract decision. | Vishwa + Vinuka (contract) |
| ~~BD-3~~ | 07 Recovery Check | `POST /api/machine/recovery-checks` → `record_recovery_check` | ✅ **Done (10 Nov 2026)**, see section 1 | Vishwa |
| **BD-4** | 08 Postmortem | Machine endpoints to **read** an incident, its AI analysis, run and recovery checks, and to **save** a postmortem | ❌ Not in the contract | Vishwa + Vinuka |
| **BD-5** | 06 Remediation | The backend must **call n8n** after an approval: `POST <n8n>/webhook/remediation`, signed with `buildSignedHeaders()`, body `{ playbook_run_id, incident_id, action_type, request_payload }`. `buildSignedHeaders` exists but nothing calls it yet. | In the contract; not implemented | Vishwa |
| **BD-6** | 06 → 07 | `request_payload.service_name` must be set when a run is requested (the recovery check needs the service name) | Not specified. `request_payload` is optional in `playbook-run.controller.ts`. Simplest fix: the backend copies `incidents.service_name` (the column exists) into the payload. | Vinuka / mobile |

How to plug a route in when it exists: 01 and 08 have a Code node named `… – BLOCKED`. Replace it with a **Sign request** Code node plus an **HTTP Request** node, copying the pattern in workflow 07 (`Sign recovery check request` → `Backend: store recovery check`). BD-2 needs no workflow change.

## 2a. Error notifications for soft failures (N-2)

Some failures don't crash a workflow (it answers normally) but need an operator. They are returned as `soft_failure: { kind, node, message }` and reported to workflow 09 ("When called with a soft failure") by the **top-level** workflows only. Sub-workflows 05 and 07 return the output of their last node to their caller, so they return `soft_failure` instead of notifying.

| kind | Reported by | When | Silent (expected) |
|---|---|---|---|
| `completion_failed` | 06 | `/complete` failed after the last attempt (or a 4xx) | — |
| `start_unconfirmed` / `start_failed` | 06 | `/start` timed out, connection error, 5xx / 401, 503 | 409 not approved, 404, 400 |
| `recovery_store_failed` | 06 (from 07) | `/recovery-checks` answered anything but 2xx | missing ids (test runs) |
| `ai_unavailable` | 01 (from 05) | Groq auth, rate limit, timeout or 5xx | invalid AI answer (schema), no evidence |
| `rca_store_failed` | 01 (from 05) | `/investigations/:id/analysis` failed | 404 `not_implemented` (BD-2 missing), blocked by BD-1/BD-2 |

One notification per kind per execution (three alerts with the AI down = one message). The message is short and redacted (no request, headers, signature, payload or URL). Crashes still reach 09 through each workflow's *Error workflow* setting, unchanged. Whether n8n runs the error workflow of a crashed **sub-workflow** has not been verified yet (real-service test).

## 3. Execution mechanism (BLOCKED)

The project has **no playbook executor** yet (Gantt tasks 30–31, `infrastructure/playbooks/`). Workflow 06 therefore:

- does not execute shell commands;
- does not accept commands from the webhook (unknown fields → 400) or from the AI;
- with `REMEDIATION_EXECUTION_MODE=disabled` (the default), answers **503 before starting the run**, so no run is left "running";
- with `REMEDIATION_EXECUTION_MODE=simulate` (tests and demo rehearsal only), records a result marked `"simulated": true, "executed": false`.

**Needed (executor owner):** an HTTP executor that accepts only `{ action, service_name, playbook_run_id }` for the four fixed actions, authenticated by the same HMAC scheme. Then replace the four `Execute: <action>` Code nodes with signed HTTP Request nodes.

## 4. Monitoring requirements (to agree with the monitoring owner)

| Need | Used by | Default in the workflows | Must be confirmed |
|---|---|---|---|
| Loki label naming the service | 02 | `LOKI_SERVICE_LABEL=service` | ✅ yes: it depends on the log shipper (promtail `job`, docker `compose_service`, …) |
| Prometheus label naming the service | 03, 07 | `PROM_SERVICE_LABEL=job` | ✅ yes |
| CPU and memory metrics | 03 | prom-client defaults `process_cpu_seconds_total`, `process_resident_memory_bytes` | yes, if the sample app does not use prom-client |
| Error-rate query | 03, **07 (required)** | none: set `PROM_QUERY_ERROR_RATE` + `PROM_THRESHOLD_ERROR_RATE` | ✅ yes. Without it, 07 answers `unable_to_verify` (by design). |
| Latency p95 and request rate queries | 03 | none (reported as `not_configured`) | optional |
| `up` metric for the service's scrape target | 07 | built-in Prometheus metric | no |
| Alertmanager `webhook_config` → `http://<n8n>/webhook/alertmanager`, with `http_config.authorization.credentials` = the token in the n8n credential | 01 | – | ✅ yes |
| Alert label naming the service | 01 | `service` (fallbacks: `service_name`, `job`, `app`) | yes |

Example Alertmanager receiver (token = the value in the n8n credential, without "Bearer"):

```yaml
receivers:
  - name: n8n-alert-intake
    webhook_configs:
      - url: http://n8n:5678/webhook/alertmanager
        send_resolved: true
        http_config:
          authorization:
            type: Bearer
            credentials_file: /etc/alertmanager/n8n-token   # file mounted from a secret
```

## 5. Credentials and configuration (set manually; never commit them)

| Name | Type in n8n | Value | Used by |
|---|---|---|---|
| **Groq API** | Credential → Header Auth | Name `Authorization`, Value `Bearer <Groq key>` | 00, 05, 08 |
| **GitHub API (read-only)** | Credential → Header Auth | Name `Authorization`, Value `Bearer <fine-grained token>` with read-only **Contents** and **Actions** on the one repository | 04 |
| **Alertmanager Webhook Token** | Credential → Header Auth | Name `Authorization`, Value `Bearer <random token>` | 01 |
| `MACHINE_SIGNING_SECRET` | Environment | Same value as the backend (≥ 32 chars) | 05, 06, 07 |
| `N8N_ENCRYPTION_KEY` | Environment | Random, ≥ 32 chars; back it up | n8n |
| `ERROR_NOTIFY_WEBHOOK_URL` | Environment (optional) | Slack/Discord incoming webhook URL | 09 |
| All other settings | Environment | See `automation/.env.example` | – |

## 6. Open decisions

| ID | Decision | Why it is open | Recommendation |
|---|---|---|---|
| **D-N8N-1** | `N8N_BLOCK_ENV_ACCESS_IN_NODE` | Contract B.3 (A5) says `true`. With `true`, a Code node cannot read `MACHINE_SIGNING_SECRET`, and n8n Community Edition has no other secret store a Code node can use (external secrets and `$secrets` are paid features). The workflows need `false`. | Keep `false`, pass **only** the listed variables into the container (done in `docker-compose.yml`), keep API keys in Credentials, limit who can edit workflows. Record this in the decision register. |
| D-N8N-2 | Recovery verdict → database status | `recovery_checks.status` allows `pending\|healthy\|unhealthy\|failed`. Mapping used: recovered → `healthy`, not recovered → `unhealthy`, unable to verify → `failed`. | Confirm with the database owner. |
| D-N8N-3 | Root cause storage | `record_ai_analysis` has `p_root_cause`; the contract body (ai-output schema) has no `root_cause` (R11). 05 sends `root_cause` as an extra field. | Add `root_cause` to the contract when BD-2 is built. |
| D-N8N-4 | Alert severity mapping | Alertmanager `warning` → incident `medium`, `page` → `critical`, unknown → `medium` | Confirm with the team. |
| D-N8N-5 | De-duplication and nonce store | Static data is per workflow, saved only for production executions and only when an execution **ends**. Concurrent duplicates are therefore not caught by n8n (reproduced in the integration test, and documented by `automation/tests/alert-dedupe.test.mjs`). **N-3 (10 Nov):** an alert is `pending` until "Confirm alert processing" marks it `confirmed` (incident created, or BD-1 not available) or releases it (creation failed, so the next delivery is processed again); a pending entry left by a crashed execution expires after `DEDUP_PENDING_MINUTES`. This does **not** solve concurrency. | Keep it as a first filter; make BD-1 idempotent on the fingerprint (database). For remediation, the database already refuses a second start. |
