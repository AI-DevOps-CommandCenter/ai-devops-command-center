# Automation – Integration Requirements and Blockers

What the n8n workflows need from other parts of the project, what is missing today, and which decisions are open.
Everything here was checked against the code on branch `feature/n8n-incident-workflow` (8 Nov 2026; updated 10 Nov 2026 for BD-3, N-1, N-2, N-3 and N-5; updated 12 Nov 2026 for the BD-5 n8n side, known issue KI-1 and the handoff list in section 7).

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
| ~~BD-3~~ | 07 Recovery Check | `POST /api/machine/recovery-checks` → `record_recovery_check` | ✅ **Done (10 Nov 2026)**, see section 1. Backend route (`aa671cb`) and the n8n side (`60e9683`): 07 signs and sends the recovery check, returns `recovery_check_id`, and reports a failed store as `recovery_store_failed` (06 notifies). Tests: backend Vitest; `npm run test:interop` (07's real request against the real route, 201/400/401/404/409/500); live n8n checks (stored as `healthy`/`unhealthy`, body matches the contract, 404 → `not_found`, 500 → `server_error`). Not tested against the real database (M9). | Vishwa |
| **BD-4** | 08 Postmortem | Machine endpoints to **read** an incident, its AI analysis, run and recovery checks, and to **save** a postmortem | ❌ Not in the contract | Vishwa + Vinuka |
| **BD-5** | 06 Remediation | The backend must **call n8n** after an approval: `POST <n8n>/webhook/remediation`, signed with `buildSignedHeaders()`, body `{ playbook_run_id, incident_id, action_type, request_payload }`. `buildSignedHeaders` exists but nothing calls it yet (checked 12 Nov: no caller in `backend/src`; `decideApprovalController` only calls `decide_approval`). | In the contract. **n8n side done and tested** (section 2a); **backend trigger not implemented** | Backend trigger: Vinuka (approval flow owner). n8n side: Vishwa (done) |
| **BD-6** | 06 → 07 | `request_payload.service_name` must be set when a run is requested (the recovery check needs the service name) | Not specified. `request_payload` is optional in `playbook-run.controller.ts`. Simplest fix: the backend copies `incidents.service_name` (the column exists) into the payload. | Vinuka / mobile |

How to plug a route in when it exists: 01 and 08 have a Code node named `… – BLOCKED`. Replace it with a **Sign request** Code node plus an **HTTP Request** node, copying the pattern in workflow 07 (`Sign recovery check request` → `Backend: store recovery check`). BD-2 needs no workflow change.

## 2a. BD-5 remediation webhook contract (n8n side: implemented)

What the backend must send, and what workflow 06 answers. Source of truth: `automation/src/nodes/06-remediation/verify-request.js`, `src/lib/hmac.js` and the generated `workflows/06-remediation.json`.

**Request**
- `POST <n8n base>/webhook/remediation`, `Content-Type: application/json`.
- Body (exactly these fields; any other field → 400): `{ playbook_run_id: uuid, incident_id: uuid, action_type: "restart"|"rollback"|"scale"|"circuit_breaker", request_payload?: object }`.
- Headers: `X-DC-Timestamp` (unix seconds), `X-DC-Nonce` (16–200 chars `[A-Za-z0-9_-]`, new for **every** request), `X-DC-Signature: sha256=<hex>`.

**HMAC signature**
- `HMAC-SHA256(MACHINE_SIGNING_SECRET, timestamp + "." + nonce + ".POST." + path + "." + rawBody)`, the same scheme and secret (≥ 32 chars) as the n8n → backend calls.
- `path` is the path n8n sees, `N8N_REMEDIATION_SIGNED_PATH` (default `/webhook/remediation`); behind a proxy that rewrites paths, set it to match.
- Sign the **exact bytes** that are sent: serialize the body once and send that string (re-serializing → 401).
- Timestamp within ±300 s of n8n's clock. Each nonce is accepted once (15-minute memory, see KI-1 for the concurrency limit).
- `buildSignedHeaders(secret, { method: "POST", path: "/webhook/remediation", body, nonce })` in `backend/src/middleware/machine-auth.ts` produces correct headers (proved by the interop test below).

**Responses**

| HTTP | When | Body (`accepted`, `message`) |
|---|---|---|
| 202 | Signature valid, mode `simulate`, backend `/start` succeeded and returned the same action | `accepted: true`, `playbook_run_id`, `action_type`, `mode` |
| 400 | Raw body missing, invalid JSON, invalid fields; or backend `/start` answered 400 | `accepted: false` + reason |
| 401 | Missing header, bad timestamp format, timestamp outside ±5 min, bad nonce format, wrong signature | `accepted: false` + reason |
| 404 | Backend `/start`: run not found | `accepted: false` |
| 409 | Nonce already used (`Replayed request.`); backend `/start` refused (run not approved, already started, playbook disabled); or run started but the database action differs from the request (the run is then completed as `failed`) | `accepted: false` + reason |
| 502 | Backend `/start` timed out, connection error, 5xx, 401 or 503: start unconfirmed or misconfigured (N-2 notification) | `accepted: false` |
| 503 | `MACHINE_SIGNING_SECRET` missing/short in n8n (`…not configured…`), **or** execution mode `disabled` | `accepted: false` + reason |

**Disabled execution (default)**: with `REMEDIATION_EXECUTION_MODE` unset or `disabled`, a fully valid signed request gets **503** with `Remediation execution integration is not available (BLOCKED: no playbook executor). The run was not started.` The backend `/start` is **not** called and the run stays `approved`. Only `simulate` (tests and demo rehearsal) continues. The nonce of that request **is** consumed: a later attempt must be signed again with a new nonce.

**Tests (n8n side, all against mocks or fakes)**
- `npm run test:interop:remediation`: requests signed by the backend's real `buildSignedHeaders()` checked by 06's real verifier: valid → accepted; wrong bytes/path/secret, forged signature, each missing header, expired timestamp, bad nonce → 401; extra field → 400; replay → 409; missing secret → 503; disabled → 503 and routed to "Respond 503", never to "Sign start request".
- `npm run test:n8n`: live n8n 2.40.5: 202, 409 (replay, not approved, action mismatch), 401 (bad HMAC, stale time), 400, and a restart in `disabled` mode → 503, 0 backend calls, run stays `approved`.
- Unit tests: start answers 409/404/400 are silent refusals; 401/503/timeout/5xx → 502 + soft failure.

**Missing: the backend trigger.** Nothing in the backend calls this webhook yet. Needed (backend owner): after `decide_approval` approves a run, send the request above. A `503`/`502`/timeout leaves the run `approved` or unconfirmed; the backend must not re-send the same signed request (new nonce and timestamp each time) and must treat `409` as "already handled or refused". Not tested yet against the real backend and database (manual test M7).

## 2b. Implementation status of N-1, N-2, N-3 and N-5 (n8n side)

| ID | What | Status |
|---|---|---|
| N-1 | Retry-safe `/complete` in 06 (max 3 attempts, 2 s / 4 s, new nonce each time, never 4xx; a 409 after an ambiguous attempt counts as completed) | ✅ Implemented (commit `60e9683`); unit tests + live n8n checks (section 1) |
| N-2 | Soft-failure notifications through 09 (section 2c) | ✅ Implemented (`60e9683`); unit tests + live n8n checks with an HTTPS test receiver. Real Slack/Discord not tested (M10) |
| N-3 | Alert de-duplication with a `pending` → `confirmed`/released state in 01 | ✅ Implemented (`60e9683`); does **not** solve concurrent duplicates (D-N8N-5) |
| N-5 | n8n published on `127.0.0.1` by default (`N8N_BIND_ADDRESS`) | ✅ Implemented (`b99ee0f`) in `docker-compose.yml` |

## 2c. Error notifications for soft failures (N-2)

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
| D-N8N-5 | De-duplication and nonce store | Static data is per workflow, saved only for production executions and only when an execution **ends**. Concurrent duplicates are therefore not caught by n8n (reproduced in the integration test, and documented by `automation/tests/alert-dedupe.test.mjs`). **N-3 (10 Nov):** an alert is `pending` until "Confirm alert processing" marks it `confirmed` (incident created, or BD-1 not available) or releases it (creation failed, so the next delivery is processed again); a pending entry left by a crashed execution expires after `DEDUP_PENDING_MINUTES`. This does **not** solve concurrency. | Keep it as a first filter; make BD-1 idempotent on the fingerprint (database). For remediation, the database already refuses a second start. The same mechanism also **loses** remediation nonces: known issue KI-1 (section 6a). |

Proposals for D-N8N-1 and for replacing the nonce store (KI-1, proposed decision D-N8N-6) are written up for the decision-register owner in `docs/automation-decision-proposals.md`. This document does not change the register.

## 6a. Known issues

### KI-1: replay nonces in workflow 06 can be lost under concurrency (open, not fixed)

**What:** workflow 06 stores the nonces it has accepted in workflow static data (`$getWorkflowStaticData('global').seenNonces`). n8n loads static data when an execution starts and saves the whole object when it ends (about 10 s later for a remediation run). Concurrent executions therefore don't see each other's nonces, and the one that ends last overwrites the others' updates (last writer wins). A nonce can be lost, and the exact same signed request can then pass n8n's replay check again **within the 5-minute timestamp window**.

**Observed (12 Nov 2026, `npm run test:n8n:replay`, live n8n 2.40.5, mock backend):**
- sequential exact replay after the execution ended → 409 `Replayed request.` from n8n, backend not called;
- concurrent identical requests → both pass n8n; the backend run-state check refused the second `/start` (one successful start);
- five simultaneous identical requests → five `/start` calls, **one** successful start, four 409;
- two concurrent requests with **different** nonces → one nonce lost; its exact replay reached `/start` again (refused by run state). Reproduced in every run (the lost nonce varies).

No run was started or completed twice. **Limits:** the backend was a mock; the production database row lock (`start_playbook_run`, `SELECT … FOR UPDATE`, approved → running) and Supabase were **not** exercised by this investigation.

**Current protection:** the backend/database run state (a run can be started once). n8n's nonce check is only reliable for requests that don't overlap.

**Recommended fix (needs a team decision):** an atomic, shared nonce store, e.g. n8n consumes each nonce through the database-backed store the backend already has (`consume_automation_nonce`, migration `000400`) via a signed machine endpoint, or another atomic mechanism. Proposal: `docs/automation-decision-proposals.md`. The S5 check in `tests/integration/run-replay-protection.mjs` must stay strict and fails until this is fixed.

## 7. Handoff: work the n8n developer cannot complete alone

| Item | Needed from | What | n8n side today |
|---|---|---|---|
| BD-5 trigger | Vinuka (backend approval flow) | After an approval, call `POST <n8n>/webhook/remediation` per section 2a (`buildSignedHeaders`, new nonce per attempt, n8n URL in backend config) | Done and tested (mocks) |
| BD-6 | Backend (Vinuka) | Set `request_payload.service_name` when a run is requested (e.g. copy `incidents.service_name`) | 06 refuses to execute without it (run completed as failed) |
| Real execution | Keshan (playbook executor) | HMAC-authenticated executor for the four fixed actions | `simulate` / `disabled` only |
| KI-1 nonce race | Backend + database team | Agree and provide an atomic shared nonce store | Documented; strict failing test kept |
| BD-1 | Backend + database team | Contract, migration and route to create an incident from an alert (idempotent on fingerprint) | 01 node "Create incident (backend) – BLOCKED" |
| BD-2 | Backend team (contract with Vishwa) | Finalize and implement the AI-analysis storage route (`/investigations/:id/analysis` or incident-level), plus `root_cause` (D-N8N-3) | 05 already signs and sends; 404 → `not_implemented` |
| D-N8N-1 | Decision-register owner (database team) / team | Confirm env access for `MACHINE_SIGNING_SECRET` or choose another secret-injection method | `false` in `docker-compose.yml`, pending decision |
