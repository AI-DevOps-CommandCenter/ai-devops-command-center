# API and Integration Contracts

**Project:** AI-Powered Mobile DevOps Command Center
**Date:** 2026-11-07
**Branch:** `feature/database-implementation`

The document has two parts:

| Part | Status | Who can build against it now |
|---|---|---|
| **A. Current REST API** | **VERIFIED** from `backend/src` (routes, controllers, services) | Mobile and backend, today |
| **B. Proposed database functions, machine endpoints and n8n/notification contracts** | **PROPOSED, NOT APPROVED.** Each item names the pending decision it depends on. | Draft only; shapes may change when the decisions are approved |

---

## Part A – Current REST API (verified)

### A.1 Conventions
- **Base URL:** `http://localhost:3000` locally (`PORT`).
- **Authentication:** `Authorization: Bearer <Supabase access token>`. The mobile app gets the token from Supabase Auth (email/password sign-in). Every `/api/*` route requires it. The backend verifies the token, then queries the database **as that user**, so RLS applies (A1, D-002).
- **Content type:** `application/json`.
- **Success shape:** `{ "success": true, "message": "...", "data": ... }`. List endpoints add `"count"`.
  - **Exception:** the remediation list returns `{ "count", "limit", "offset", "data" }` without `success`. That is an existing contract, kept as is.
- **Error shape:** `{ "success": false, "message": "..." }`. Zod validation errors (new endpoints) add `"errors": [{ "location", "path", "message" }]`.
- **Status codes:**

| Code | Meaning |
|---|---|
| 200 | OK |
| 201 | Created |
| 400 | Invalid input, or malformed JSON |
| 401 | Missing, invalid or expired token |
| 403 | Role not allowed |
| 404 | Not found, or not visible to this user under RLS |
| 413 | Body too large |
| 429 | Rate limit |
| 500 | Server error |

### A.2 Endpoints

| Method & path | Who | Body / query | Notes |
|---|---|---|---|
| `GET /` | anyone | – | Health message |
| `GET /api/me` | any user | – | `{ success, message, user: { id, email } }` |
| `GET /api/dashboard/summary` | any user | – | Counts visible to the caller: `total, open, investigating, identified, mitigating, resolved, closed, critical` |
| `POST /api/incidents` | any user | `title`*, `service_name`*, `severity`* (`critical/high/medium/low/info`), `description`, `environment` | Created with `status: open`, `source: manual`, `created_by` = caller |
| `GET /api/incidents` | any user | query: `status`, `severity`, `service_name`, `limit`, `offset` | Users see their own incidents; operators and admins see all |
| `GET /api/incidents/:id` | owner, operator, admin | – | 404 when not visible |
| `PATCH /api/incidents/:id` | operator, admin (RLS) | `title`, `description`, `service_name`, `environment`, `severity`, `status` (`open/investigating/identified/mitigating/resolved/closed`) | No transition rules yet (GAP-07, U11) |
| `POST /api/investigations` | incident owner, operator, admin | `incident_id`*, `status`, `summary`, `root_cause`, `evidence`, `ai_model` | Accepts client-supplied AI fields (A9-Q2 pending) |
| `GET /api/investigations?incident_id=` | as incident | query: `incident_id`* | |
| `GET /api/investigations/:id` | as incident | – | |
| `PATCH /api/investigations/:id` | operator, admin | `status`, `summary`, `root_cause`, `evidence`, `ai_model` | |
| `POST /api/approvals` | any user | `incident_id`* | Creates a `pending` approval requested by the caller |
| `GET /api/approvals` | requester, admin | query: `status` | |
| `GET /api/approvals/:id` | requester, admin | – | |
| `PATCH /api/approvals/:id/decision` | **admin**, not the requester | `status`* (`approved/rejected`), `comments` | Decided approvals cannot change |
| `POST /api/playbook-runs` | incident owner, operator, admin | `playbook_id`*, `incident_id`*, `request_payload` | Status `pending_approval`, or `approved` when the playbook has `requires_approval = false` (GAP, A4) |
| `GET /api/playbook-runs` | requester, operator, admin | query: `status`, `incident_id` | |
| `GET /api/playbook-runs/:id` | requester, operator, admin | – | |
| `PATCH /api/playbook-runs/:id/decision` | **operator or admin**, not the requester | `status`* (`approved/rejected`) | Second approval path (A3 pending) |
| `POST /api/postmortems` | operator, admin | `incident_id`*, `summary`, `root_cause`, `impact`, `timeline`, `lessons_learned`, `action_items` | One per incident |
| `GET /api/postmortems` | as incident | query: `incident_id`, `limit`, `offset` | |
| `GET /api/postmortems/:id` | as incident | – | |
| `PATCH /api/postmortems/:id` | operator, admin | same fields as POST except `incident_id` | |
| `POST /api/remediation-executions` | operator, admin | `incident_id`*, `playbook_id`, `input_data` | **No approval check** (GAP-06, A3) |
| `GET /api/remediation-executions` | as incident | query: `incident_id`, `playbook_id`, `status`, `limit`, `offset` | Response without `success` (see A.1) |
| `GET /api/remediation-executions/:id` | as incident | – | |
| `PATCH /api/remediation-executions/:id` | operator, admin | `status`, `output_data`, `started_at`, `completed_at`, ... | Client-set status and timestamps (GAP-06) |
| `GET /api/audit-logs` | admin | query: `action`, `entity_type`, `limit`, `offset` | |
| `GET /api/admin/users` | admin | query: `role`, `limit`, `offset` | |
| `PATCH /api/admin/users/:id/role` | admin, not self | `role`* (`user/admin/operator`) | Calls `admin_update_user_role()` |
| `GET/POST /api/admin/playbooks`, `PATCH/DELETE /api/admin/playbooks/:id` | admin | `name`, `description`, `action_type` (`restart/rollback/scale/circuit_breaker`), `configuration`, `enabled`, `requires_approval` | |
| `GET/POST /api/admin/integrations`, `PATCH/DELETE /api/admin/integrations/:id` | admin | `name`, `provider`, `is_active`, `settings` | Don't store secrets in `settings` (A2-Q4) |

`*` = required. "as incident" = visible when the caller can see the incident (owner, operator or admin).

### A.3 Examples

**Create an incident**
```http
POST /api/incidents
Authorization: Bearer <access token>
Content-Type: application/json

{ "title": "Checkout latency", "service_name": "checkout-api", "severity": "high",
  "description": "p95 above 2s", "environment": "staging" }
```
```json
201 { "success": true, "message": "Incident created successfully.",
      "data": { "id": "…", "title": "Checkout latency", "service_name": "checkout-api",
                "severity": "high", "status": "open", "source": "manual",
                "created_by": "…", "detected_at": "…", "created_at": "…" } }
400 { "success": false, "message": "Title, service name and a valid severity are required." }
401 { "success": false, "message": "Authentication token is required." }
```

**Request a playbook run**
```http
POST /api/playbook-runs
{ "playbook_id": "…", "incident_id": "…", "request_payload": { "target": "checkout-api" } }
```
```json
201 { "success": true, "data": { "id": "…", "status": "pending_approval", "approval_required": true, … } }
```

**Decide an approval (admin)**
```http
PATCH /api/approvals/<id>/decision
{ "status": "approved", "comments": "Restart is safe" }
```
```json
200 { "success": true, "data": { "id": "…", "status": "approved", "approver_id": "<admin id>", "decided_at": "…" } }
403 { "success": false, "message": "Only administrators can decide approval requests." }
```

### A.4 Mobile data models (from the database columns returned by the API)

| Model | Fields |
|---|---|
| Profile | `id, full_name, email, role (user/admin/operator), created_at, updated_at` |
| Incident | `id, title, description, severity, status, source, service_name, environment, service_id?, deployment_id?, created_by, detected_at, acknowledged_at, resolved_at, created_at, updated_at` |
| Investigation | `id, incident_id, status (pending/running/completed/failed), summary, root_cause, evidence, ai_model, created_at` |
| Approval | `id, incident_id, requested_by, approver_id, status (pending/approved/rejected), comments, requested_at, decided_at` |
| Playbook | `id, name, description, action_type, configuration, enabled, requires_approval, created_at, updated_at` |
| PlaybookRun | `id, playbook_id, incident_id, requested_by, approved_by, status (pending_approval/approved/running/success/failed/rejected/cancelled), approval_required, request_payload, result_payload, requested_at, approved_at, started_at, completed_at, automation_run_id?` |
| RemediationExecution (legacy) | `id, incident_id, playbook_id, triggered_by, status (pending/running/succeeded/failed/cancelled), input_data, output_data, started_at, completed_at, created_at` |
| Postmortem | `id, incident_id, summary, root_cause, impact, timeline, lessons_learned, action_items, created_by, created_at, updated_at` |
| DashboardSummary | `total, open, investigating, identified, mitigating, resolved, closed, critical` |

Treat every timestamp as ISO-8601 UTC and every `id` as a UUID string. Fields marked `?` are nullable links added by the new migrations; the current API doesn't set them yet.

**Action type naming:** the project brief says `restart_service`, `rollback_deployment`, `scale_service`, `circuit_breaker`. The database, and therefore the API, uses `restart`, `rollback`, `scale`, `circuit_breaker`. The mobile app should map labels to the stored values. Changing the stored values is open question R13.

---

## Part B – Workflow contracts (APPROVED A2–A7, implemented locally 2026-11-07)

These replace the direct table writes in Part A (migrations 000400–000700). Part A's approval, playbook-run, remediation and audit **writes** stop working when those migrations are applied, so the backend must switch in the same release (handover §1a). All of them:
- run inside PostgreSQL as narrow `SECURITY DEFINER` functions with `search_path = ''`;
- check `auth.uid()` and the caller's role themselves;
- write the audit entry in the same transaction;
- are called by the backend with the **user's JWT** through `supabase.rpc(...)` (D-002).

### B.1 Error codes (implemented)

Functions raise these custom SQLSTATEs; the backend maps them, and PostgreSQL's own errors, to HTTP.

| SQLSTATE | Meaning | HTTP |
|---|---|---|
| `DC401` | Not authenticated | 401 |
| `DC403` | Role not allowed, or separation of duties violated | 403 |
| `DC404` | Not found or not visible | 404 |
| `DC409` | Invalid state transition, duplicate request, already decided | 409 |
| `DC422` | Invalid input | 400 |
| `23505` unique violation | Duplicate (e.g. same n8n execution) | 409 |
| `23503` / `23001` FK or RESTRICT violation | Referenced row missing or in use | 409 |
| `23514` check violation | Invalid value | 400 |
| `42501` insufficient privilege / RLS | Not allowed | 403 |

### B.2 Workflow functions

Every function below writes its audit entry (and, where relevant, a timeline event and notifications) in the same transaction. If any of these writes fails, the whole action fails.

| Function (implemented) | Caller | Effect |
|---|---|---|
| `request_playbook_run(p_incident_id, p_playbook_id, p_idempotency_key = NULL, p_request_payload = '{}')` → `{run_id, status, approval_id, created}` | user (own incidents), operator, admin | Playbook must be enabled; incident not resolved/closed. **Always** creates a `pending` approval linked 1:1 (A4). Same requester + key returns the same run (`created: false`); the same key for another request ⇒ DC409. A second active run for the same incident+playbook ⇒ DC409. Notifies every admin/operator except the requester. |
| `decide_approval(p_approval_id, p_decision 'approved'\|'rejected', p_reason = NULL)` | operator, admin (A3-Q1) | Never on one's own request (DC403); only `pending` (DC409). The approver comes from the JWT. Moves the linked run to `approved`/`rejected` and notifies the requester. |
| `cancel_approval(p_approval_id, p_reason = NULL)` | the requester only | `pending → cancelled`, and the linked run too |
| `cancel_playbook_run(p_run_id, p_reason)` | requester or manager (pending); manager with a reason of 5+ chars (approved/running) | `→ cancelled`; a pending approval is cancelled too |
| `start_playbook_run(p_run_id, p_n8n_execution_id, p_workflow_name = 'remediation')` → `{run_id, status, automation_run_id, incident_id, action_type, request_payload}` | **automation** only | Requires run `approved`, playbook enabled and approval `approved`. A second start ⇒ DC409; a reused execution id ⇒ `23505`. |
| `complete_playbook_run(p_run_id, p_status 'success'\|'failed', p_result = '{}', p_n8n_execution_id = NULL, p_reason = NULL)` | automation (execution id must match, else DC403); operator/admin **manual override** with a reason of 5+ chars (A3-Q3) | `running →` final. Credential-like keys are removed from `p_result`. A manual override is audited as `PLAYBOOK_RUN_COMPLETED_MANUALLY`. |
| `record_ai_analysis(p_incident_id, p_investigation_id, p_model_name, p_summary, p_root_cause, p_severity, p_confidence, p_evidence, p_recommended_action)` → id | **automation** only | The investigation must belong to the incident; the table CHECKs validate values |
| `record_recovery_check(p_incident_id, p_playbook_run_id, p_status, p_check_type = NULL, p_details = '{}')` → id | automation, operator, admin | The run must belong to the incident; `checked_by` comes from the JWT |
| `add_incident_event(p_incident_id, p_event_type, p_message, p_metadata = '{}', p_level = 'info')` → id | operator/admin: `comment` only. automation: `log, comment, investigation, remediation, recovery, notification` | Append-only timeline. `approval`/`status_change` events come only from the workflow functions. |
| `register_device_token(p_device_token, p_platform)` / `unregister_device_token(p_device_token)` | the signed-in human (self) | The user comes from the JWT. A token moves to the account currently signed in on that device. |
| `mark_notification_read(p_notification_id)` | the recipient | |
| `create_notification(p_user_id \| NULL, p_incident_id, p_title, p_message, p_channels = {in_app,push})` → id | **automation** only (humans cannot notify others) | `p_user_id` NULL = team broadcast (`slack`/`discord` only) |
| `claim_notification_deliveries(p_limit = 50)` → rows `{delivery_id, channel, attempt_count, notification_id, user_id, incident_id, title, message, recipient_email (email only), device_tokens (push only)}` | **automation** only | Claims pending deliveries not attempted in the last 2 minutes (at least once) |
| `record_notification_delivery(p_delivery_id, p_status 'sent'\|'delivered'\|'failed', p_provider_message_id, p_error_message)` | **automation** only | `failed`/`delivered` are final |
| `consume_automation_nonce(p_nonce, p_signed_at)` | **automation** only | Replay protection: ±5 minutes; each nonce once (DC409) |
| `current_app_role()` | any signed-in user | Returns the caller's role |
| Internal, **no client EXECUTE**: `require_app_role`, `log_audit_event`, `write_incident_event`, `write_notification`, `notify_approvers`, `redact_sensitive` | the functions above | |
| **Not implemented:** `update_incident_status` | | Waiting for U11 (recovery rule) |

**Example: request a run**
```ts
const { data, error } = await req.userSupabase.rpc("request_playbook_run", {
  p_incident_id: "…", p_playbook_id: "…",
  p_idempotency_key: "mobile-7f3c…", p_request_payload: { target: "checkout-api" }
});
// data  -> { run_id: "…", status: "pending_approval", approval_id: "…", created: true }
// error -> { code: "DC409", message: "An active run already exists for this incident and playbook." }
```

**Example: decide**
```ts
await req.userSupabase.rpc("decide_approval", { p_approval_id: "…", p_decision: "approved", p_reason: "Safe" });
// error.code "DC403" when the caller requested it; "DC409" when it is no longer pending
```

### B.3 n8n integration (A5, implemented on the database and backend side)

**Rules (A5, D-001):**
- n8n never holds service_role, the database URL or any Supabase key.
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=true`.
- HTTPS.
- A pinned n8n image.

**Signing (both directions, the same scheme):** `backend/src/middleware/machine-auth.ts`
```http
X-DC-Timestamp: 1762510000                      (unix seconds)
X-DC-Nonce:     <16-200 chars, A-Z a-z 0-9 _ ->   (unique per request)
X-DC-Signature: sha256=<hex HMAC-SHA256(secret, canonical)>

canonical = timestamp + "." + nonce + "." + METHOD + "." + path + "." + rawBody
```
- **Why method and path are signed:** a signature for one endpoint can't be replayed on another. (The earlier proposal signed only `timestamp + "." + body`; n8n must use the canonical form above.)
- **Rejected:** a timestamp more than 5 minutes off; a nonce already used (backend: DB function `consume_automation_nonce`); a wrong signature; any request when replay protection is unavailable (503, fail closed).
- **Secret:** at least 32 characters, held only in the backend's and n8n's secret stores (A2-Q4/A5-Q2 open).

**Backend → n8n (start a remediation workflow):**
```http
POST https://<n8n host>/webhook/remediation
X-DC-Timestamp / X-DC-Nonce / X-DC-Signature   (built with buildSignedHeaders())
{ "playbook_run_id": "…", "incident_id": "…", "action_type": "restart", "request_payload": { … } }
```
n8n verifies the same canonical string and rejects stale or replayed requests.

**n8n → backend (machine endpoints; to be mounted with `machineAuth()` + `express.json({ verify: captureRawBody })`):**

| Endpoint | Body | Calls |
|---|---|---|
| `POST /api/machine/playbook-runs/:id/start` | `{ n8n_execution_id, workflow_name }` | `start_playbook_run` |
| `POST /api/machine/playbook-runs/:id/complete` | `{ n8n_execution_id, status: "success"\|"failed", result }` | `complete_playbook_run` |
| `POST /api/machine/investigations/:id/analysis` | AI output (`automation/schemas/ai-output.schema.json`: `summary, severity, evidence[], confidence, recommended_action`) plus `model_name` | `record_ai_analysis` |
| `POST /api/machine/recovery-checks` | `{ incident_id, playbook_run_id, status, check_type, details }` | `record_recovery_check` |
| `POST /api/machine/incident-events` | `{ incident_id, event_type, message, metadata }` | `add_incident_event` |

- **Database identity:** after verifying the signature, the backend calls the function with the **automation identity's JWT** (role `automation`, assignable only by the database owner).
- **Duplicate deliveries:** the same `n8n_execution_id` returns 409 (`automation_runs_n8n_execution_id_key`). Tested in suites 08 and 10.
- **Completion** must use the execution id that started the run (else DC403).

**AI output → database mapping:**

| AI output | Database column |
|---|---|
| `summary` | `ai_analyses.summary` |
| `severity` | `severity` (no `info` value; R11) |
| `evidence` | `evidence` |
| `confidence` (0–1) | `confidence` |
| `recommended_action` | `recommended_action` (same value set as the playbooks' action types) |
| `title` | no column (unmapped) |
| — | `root_cause`: the AI schema has no field for it (R11) |

### B.4 Notifications (A6, implemented)
- **Module:** the backend notification module (A6-Q1, R6).
- **Inbox:** one `notifications` row per user and item. Users read their own rows directly (RLS) and mark them read with `mark_notification_read`.
- **Delivery:** one `notification_deliveries` row per external channel. The module calls `claim_notification_deliveries`, sends each delivery, then calls `record_notification_delivery`. No client can read the table.
- **Device tokens:** `register_device_token` uses the user ID from the JWT, never from the request body.
- **Allowed channels:** `in_app, push, email, slack, discord` (A6 / R4). `telegram` was removed.
- **Team broadcasts:** `user_id` NULL, `slack`/`discord` only.
- **Provider credentials** (FCM, SMTP, Slack/Discord webhooks): kept in the backend's secret store, never in mobile, n8n or the database.
