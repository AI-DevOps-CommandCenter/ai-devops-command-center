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

## Part B – Proposed contracts (NOT APPROVED)

These replace the direct table writes in Part A once the decisions are approved. All of them:
- run inside PostgreSQL as narrow `SECURITY DEFINER` functions with `search_path = ''`;
- check `auth.uid()` and the caller's role themselves;
- write the audit entry in the same transaction;
- are called by the backend with the **user's JWT** through `supabase.rpc(...)` (D-002).

### B.1 Error codes (proposed, pending A2)

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

| Function (proposed) | Caller | Effect | Depends on |
|---|---|---|---|
| `request_playbook_run(p_incident_id, p_playbook_id, p_idempotency_key, p_request_payload)` | user, operator, admin | Checks the playbook is enabled and the caller may see the incident. Copies `approval_required`. Creates a `pending` approval when protected. The same idempotency key returns the same run. | A3, A4, U2 |
| `decide_approval(p_approval_id, p_decision, p_reason)` | approver roles (A3-Q1) | Compare-and-set on `pending`. Approver is `auth.uid()` and ≠ requester. Moves the linked run to `approved` or `rejected`. | A3 |
| `cancel_approval(p_approval_id, p_reason)` | requester | `pending → cancelled` | A3 |
| `cancel_playbook_run(p_run_id, p_reason)` | requester (pending), managers (approved/running) | | A3 |
| `start_playbook_run(p_run_id, p_n8n_execution_id)` | automation identity | Requires `approved`; protected ⇒ approval `approved`. Creates `automation_runs`. Duplicate execution ID ⇒ `23505`. | A3, A5 |
| `complete_playbook_run(p_run_id, p_status, p_result, p_n8n_execution_id)` | automation (manual override per A3-Q3) | `running → success/failed`; records the error payload | A3, A5 |
| `record_ai_analysis(p_incident_id, p_investigation_id, p_model_name, p_summary, p_root_cause, p_severity, p_confidence, p_evidence, p_recommended_action)` | automation | Writes `ai_analyses` and a timeline event | A5, A9-Q2 |
| `record_recovery_check(p_incident_id, p_playbook_run_id, p_status, p_check_type, p_details)` | automation, managers | Writes `recovery_checks` and a timeline event | A3, U11 |
| `update_incident_status(p_incident_id, p_status, p_reason)` | managers | Enforces allowed transitions. `resolved` needs a healthy recovery check after the last successful run, or an override with a reason. | A3, U11 |
| `add_incident_event(p_incident_id, p_event_type, p_message, p_metadata)` | functions, automation, managers (comments) | Append-only timeline | A7 |
| `register_device_token(p_device_token, p_platform)` | user (self) | Upsert on the caller's own token | A6 |
| `create_notification(p_user_id, p_incident_id, p_title, p_message, p_channels)` | functions, automation | Inbox row plus one delivery row per channel | A6 |
| `log_audit_event(...)` | **internal only**, no client EXECUTE | Called inside the functions above; failure aborts the action (A7-Q1) | A7 |

**Example: request a run (proposed)**
```ts
const { data, error } = await req.userSupabase.rpc("request_playbook_run", {
  p_incident_id: "…", p_playbook_id: "…",
  p_idempotency_key: "mobile-7f3c…", p_request_payload: { target: "checkout-api" }
});
// data  -> { run_id: "…", status: "pending_approval", approval_id: "…" }
// error -> { code: "DC409", message: "An active run already exists for this incident and playbook." }
```

**Example: decide (proposed)**
```ts
await req.userSupabase.rpc("decide_approval", { p_approval_id: "…", p_decision: "approved", p_reason: "Safe" });
// error.code "DC403" when the caller requested it; "DC409" when it is no longer pending
```

### B.3 n8n integration (proposed, pending A5)

**Rules that hold under every option (D-001):**
- n8n never holds service_role or the database URL.
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=true`.
- HTTPS.
- A pinned n8n image.

**Backend → n8n (start a remediation workflow):**
```http
POST https://<n8n host>/webhook/remediation
X-DC-Timestamp: 1762510000
X-DC-Signature: sha256=<HMAC-SHA256(secret, timestamp + "." + body)>
{ "playbook_run_id": "…", "incident_id": "…", "action_type": "restart", "request_payload": { … } }
```
n8n rejects requests older than 5 minutes and any whose signature doesn't match.

**n8n → backend (machine endpoints, proposed paths):**

| Endpoint | Body | Calls |
|---|---|---|
| `POST /api/machine/playbook-runs/:id/start` | `{ n8n_execution_id, workflow_name }` | `start_playbook_run` |
| `POST /api/machine/playbook-runs/:id/complete` | `{ n8n_execution_id, status: "success"\|"failed", result }` | `complete_playbook_run` |
| `POST /api/machine/investigations/:id/analysis` | AI output (`automation/schemas/ai-output.schema.json`: `summary, severity, evidence[], confidence, recommended_action`) plus `model_name` | `record_ai_analysis` |
| `POST /api/machine/recovery-checks` | `{ incident_id, playbook_run_id, status, check_type, details }` | `record_recovery_check` |
| `POST /api/machine/incident-events` | `{ incident_id, event_type, message, metadata }` | `add_incident_event` |

- **Signing:** each request carries the same HMAC headers plus `X-DC-Nonce`, and the backend rejects any nonce it has already seen.
- **Database identity:** the backend uses the automation identity (A5) for the database call.
- **Duplicate deliveries:** the same `n8n_execution_id` returns 409 (`automation_runs_n8n_execution_id_key`). Tested locally in suite 08.

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

### B.4 Notifications (proposed, pending A6/R6)
- **Inbox:** one `notifications` row per user and item.
- **Delivery:** one `notification_deliveries` row per channel or device attempt. The table exists now (migration 000200) with no client access.
- **Device tokens:** registered with the user's JWT. The user ID comes from the token, never from the request body.
- **Allowed channels:** `in_app, push, email, telegram`. Slack and Discord from the mobile settings screen aren't supported (R4).
- **FCM server credentials:** kept in the backend's secret store, never in mobile or n8n.
