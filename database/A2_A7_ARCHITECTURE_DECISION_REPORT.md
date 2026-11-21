# A2–A7 Architecture Decision Report (with proposed A8–A10)

**Project:** AI-Powered Mobile DevOps Command Center
**Supabase project:** `devops-command-center` (ref `hjqvjztbsndgyooyadup`)
**Date:** 2026-11-07
**Branch at time of audit:** `feature/backend-api`

**Decision status:**
- **A1 – APPROVED** (2026-11-07).
- **A2, A3, A4, A5, A6, A7 – PROPOSED / PENDING APPROVAL** (as defined in the committed Phase 19 documents).
- **A8, A9, A10 – PROPOSED NEW DECISION — NOT IN THE COMMITTED REGISTER — NOT APPROVED.** Pending acceptance; see §0.
- Nothing in this report is approved or implemented.

> ## ⛔ IMPLEMENTATION BLOCKER
> **No migration SQL or live database changes until all required decisions in the committed A2–A7 register have been approved.**

**A8–A10 (proposed additions):** accepting A8–A10 into the register, and any additional implementation gates they introduce, require explicit approval (question Q-X1).

This report recommends; it does not implement. No code, SQL, Supabase setting or live data was changed while preparing it.

### Evidence labels

| Label | Meaning |
|---|---|
| **[V-LIVE]** | Verified on the live database by the project owner (read-only SQL Editor queries, 2026-11-07), as recorded in the Phase 19 documents. |
| **[V-SCHEMA]** | Verified in `database-backups/public-schema.sql` (export of the live `public` schema). |
| **[V-BACKUP]** | Verified by reading the local backup file offline. |
| **[V-CODE]** | Verified in repository code (`git show`, read-only). `B:` = `origin/feature/backend-api-database:backend/src/`. |
| **[INFERENCE]** | Derived from verified facts, not directly proven or tested. |
| **[UNKNOWN]** | Information not available in the repository or the recorded live results. |
| **[REC]** | Recommendation, pending approval. |

---

## 0. Decision numbering (source of truth: committed Phase 19 documents)

The decision register in the committed Phase 19 documents (commits `fff81bf`, `56c6b82`: `MIGRATION_EXECUTION_PLAN.md` "Architecture decisions", `PHASE19_FINAL_VERIFICATION_REPORT.md` §10–§11) is the **source of truth**. This report uses those numbers and definitions **unchanged**.

### 0.1 Committed register (unchanged)

| # | Committed definition | Status |
|---|---|---|
| A1 | Canonical backend branch | **APPROVED** 2026-11-07 |
| A2 | User-token/RLS vs service-role/backend-only; controlled privileged mechanism and final grant/RLS boundary | PENDING |
| A3 | Canonical approval authority and authorized approver roles | PENDING |
| A4 | No-approval playbook execution rules | PENDING |
| A5 | Secure n8n integration identity and webhook authentication | PENDING |
| A6 | Notifications authentication and database compatibility | PENDING |
| A7 | Trusted audit logging (function-only writes; behaviour when an audit write fails) | PENDING |

### 0.2 Audit topics mapped to the register

| Audit topic (requested) | Mapped to | Section |
|---|---|---|
| Privileged backend operations & security boundary | **A2** | §2 |
| Approval & remediation workflow – authority, lifecycle, separation of duties, execution, idempotency, failure | **A3** | §3 |
| Approval & remediation workflow – approval-required vs no-approval playbooks | **A4** | §3 (marked A4) |
| Identity & automation actors – n8n automation identity and machine authentication | **A5** | §4 |
| Identity & automation actors – notifications service identity and compatibility | **A6** | §4 |
| Audit & incident history | **A7** – incident timeline (`incident_events`) added as a proposed extension of A7's scope | §5 |
| Existing database reconciliation | **A8 – PROPOSED NEW DECISION — NOT IN THE COMMITTED REGISTER — NOT APPROVED** (no committed number covers it) | §6 |
| Identity & automation actors – general actor model (user/operator/admin/system/AI attribution) | **A9 – PROPOSED NEW DECISION — NOT IN THE COMMITTED REGISTER — NOT APPROVED** (A5/A6 cover only the two machine identities) | §4 (marked A9) |
| Migration & deployment strategy | **A10 – PROPOSED NEW DECISION — NOT IN THE COMMITTED REGISTER — NOT APPROVED** (builds on the plan's stages 0–13 and U13) | §7 |

Accepting A8–A10 into the register is question **Q-X1** (§12).

---

## 1. Executive summary

**Current state (verified):**
- **Database [V-LIVE/V-SCHEMA]:** 18 `public` tables, RLS enabled on all, 31 permissive policies on 12 tables. Six functions; one is called by the app (`admin_update_user_role`).
- **No workflow enforcement in the database [V-LIVE]:** no triggers on the workflow tables, and no constraints for pending-only approvals, approver separation, approval-before-execution or audit immutability.
- **Backend [V-CODE]:** the approved base (`origin/feature/backend-api-database`) passes each user's login token through to Supabase, so RLS applies. Important workflow rules exist only in backend code.
  - Two disconnected approval systems.
  - Auto-approved runs.
  - Remediation without any approval check.
  - Best-effort audit logging.
- **Notifications and n8n [V-CODE]:**
  - The notifications service uses service_role with no route authentication.
  - n8n has no workflows or webhook code. Its environment template lists the service_role key and a direct database URL.
- **Schema source of truth [V-CODE + INFERENCE]:** the repository's `schema.sql` defines only 12 of the 18 live tables. Live data contains only 2 users, and most records are test data.

**Recommended direction (proposed):**

| Decision | Recommendation (short) |
|---|---|
| **A2** | User JWT + RLS for normal operations. Narrow SECURITY DEFINER functions for every workflow-critical write. **No runtime service_role**; any Supabase Auth admin need goes in an isolated, audited module. |
| **A3** | One approval model: `approvals` linked 1:1 to `playbook_runs`. Every run state change goes through a function, with compare-and-set transitions, idempotency keys, separation of duties and immutable decisions. Retire `remediation_executions` as a write path. |
| **A4** | No-approval runs allowed only for explicitly non-protected action types; restart/rollback always protected; `approval_required` copied onto each run when it is created. |
| **A5** | A dedicated, limited automation identity for n8n (Supabase Auth user with a new `automation` role), via authenticated backend machine endpoints; never service_role or a direct database URL. |
| **A6** | Notifications service: authenticated machine calls only, user identity from the JWT, no service_role, table/column names aligned with the schema. |
| **A7** | `audit_logs` = append-only, trusted, written inside functions. `incident_events` = the user-facing incident timeline. Both with actor attribution, a retention policy and redaction rules. |
| **A8** *(proposed new decision — not in the committed register — not approved)* | Additive reconciliation to the 18-table target. Keep all 46 existing rows with their IDs. Retire 3 legacy tables only after sign-off. Make one versioned schema the source of truth. |
| **A9** *(proposed new decision — not in the committed register — not approved)* | Actor types `user` / `operator` / `admin` / `automation` (n8n) / `system` (database) / `ai` (attribution label only). Every record carries `actor_type` + `actor_id`. No actor can raise its own role or decide approvals unless it is a human. |
| **A10** *(proposed new decision — not in the committed register — not approved)* | A versioned migration repository. Rehearsal on a separate non-production environment from a proven restore. Fixed execution identity. Additive-first stages with gates, pre/post validation, a timed rollback and owner sign-off. |

**Recommended approval order:** A8 → A9 → A2 → A5 → A6 → A3 → A4 → A7 → A10 (rationale in §9).

---

## 2. A2 – Privileged Backend Operations & Security Boundary

*Committed definition: user-token/RLS vs service-role/backend-only; controlled privileged mechanism and final grant/RLS boundary. Status: PENDING.*

### 2.1 Current implementation (verified)
- **Login check:** `supabase.auth.getUser(token)` in `B:middleware/auth.ts:41`. No profile or role check at login; controllers look up the role themselves (`B:services/approval.service.ts:9-24`) [V-CODE].
- **Token passed through:** a client is created per request with the caller's JWT and the publishable key (`B:config/supabase.ts:6,20-37`; `B:middleware/auth.ts:57`). No service_role anywhere in B [V-CODE].
- **Backend role checks:**
  - **Present:** admin, admin-playbook, admin-integration, approval decide, audit read, playbook-run decide, postmortem and remediation controllers.
  - **Absent:** incidents, investigations, dashboard [V-CODE].
- **service_role users:**
  - Current branch `backend/src/lib/supabase.ts:7,15-23`, guarded by `requireAuth`/`requireRole` [V-CODE].
  - Notifications service `origin/feature/notifications:notifications/src/services/supabase.service.ts:11,15`, with **no** route authentication (`notifications/src/routes/notifications.routes.ts:75-183`) [V-CODE] (→ A6).
- **Functions:**
  - SECURITY DEFINER: `admin_update_user_role`, `is_admin`, `is_incident_manager`, `handle_new_user`, `rls_auto_enable`. Not SECURITY DEFINER: `set_updated_at` [V-SCHEMA].
  - EXECUTE for `authenticated` on all of them; for `anon` on `handle_new_user`, `rls_auto_enable`, `set_updated_at` (P3c) [V-LIVE].
  - Only `admin_update_user_role` is called by code (`B:services/admin.service.ts:44-47`) [V-CODE].
- **Default privileges [V-LIVE, P3b]:** new tables created by `postgres` give `anon`/`authenticated` TRUNCATE, REFERENCES, TRIGGER and MAINTAIN (`Dxtm`). New functions are `postgres`-only. SQL Editor runs as `postgres` (P3d).
- **n8n [V-CODE]** (identity decision → A5):
  - No workflow files (`automation/workflows/.gitkeep` only) and no webhook endpoint in any backend.
  - `automation/docker-compose.yml`: `N8N_PROTOCOL: "http"` (line 11), `N8N_BLOCK_ENV_ACCESS_IN_NODE: "false"` (line 19), image `:latest` (line 3).
  - Root `.env.example` on that branch lists `SUPABASE_SERVICE_ROLE_KEY` (line 18) and `SUPABASE_DB_URL` (line 19), alongside GitHub and AWS credentials.
- **Secrets handling [V-CODE]:** `.env`, `.env.*` are git-ignored (`.gitignore:2-4`). `integrations.settings` is free JSON [V-SCHEMA]. Whether real secrets are stored there: **[UNKNOWN]** (0 integration rows today [V-BACKUP]).

### 2.2 Problems and risks
1. Workflow rules that live only in the backend can be bypassed by calling Supabase directly with a user's own JWT (report §9.3 I1–I4, **inference, not tested**).
2. The notifications service gives unauthenticated callers service_role-backed access (→ A6).
3. The planned n8n environment would hold service_role and a direct database URL, and allows workflows to read all environment variables. Both conflict with A1 (→ A5).
4. Unnecessary client EXECUTE on trigger functions (not a vulnerability by itself, P3c).
5. Inherited `Dxtm` (incl. TRUNCATE, which RLS does not restrict) on any new table.

### 2.3 Alternatives

| Option | Description | For | Against |
|---|---|---|---|
| **A** | User JWT forwarded by the backend; RLS + explicit grants | Least privilege; already how B works | Cannot enforce multi-step rules alone |
| **B** | Narrow SECURITY DEFINER functions for critical writes | One authoritative rule, on every path; audit in the same transaction | SQL logic to test; a careless definer function is a privilege-escalation risk |
| **C** | Dedicated automation identity for n8n via authenticated backend endpoints (detail → A5) | No service_role in n8n; attributable; restricted to a few functions | Needs an identity design and credential rotation |
| **D** | Server-side service_role | Can do anything | Bypasses everything; one bug or leak = full access; conflicts with A1 unless isolated |

### 2.4 Recommendation [REC]
**A + B + C, and D only as an isolated exception (default: none at runtime).**
1. **Normal operations (A):**
   - Backend checks the token, profile and role (port the `requireAuth`/`requireRole` middleware from `feature/backend-api`) and validates input (zod).
   - It then calls Supabase with the user's JWT.
2. **Critical writes (B):** approvals, run lifecycle, incident status transitions, recovery checks and audit.
   - Done via functions that check `auth.uid()` and the role internally, use `SET search_path = ''`, have explicit EXECUTE grants, and write audit in the same transaction.
   - **Revoke** direct client INSERT/UPDATE on `approvals`, `playbook_runs`, `remediation_executions` and `audit_logs`.
3. **n8n (C):** see A5.
   - Authenticated machine endpoints on the backend.
   - In the database, the automation identity may execute only machine functions (complete run, record AI analysis, record recovery check). **It may never decide approvals.**
4. **service_role (D):** only for Supabase Auth admin tasks that cannot be done otherwise.
   - Kept in a separate server module, outside the user request path, with each use audited.
   - Never in Flutter, n8n or the notifications service.
5. **Secrets:**
   - Secrets stay in the backend's and n8n's own secret stores, never in git and never in shared `.env` templates.
   - Integration secrets go in Supabase Vault (references only in `integrations.settings`).
   - Set `N8N_BLOCK_ENV_ACCESS_IN_NODE` to `true`; use HTTPS; pin image versions.
6. **Grants hygiene:**
   - Revoke the inherited `Dxtm` from client roles on new tables.
   - Remove unnecessary client EXECUTE on trigger functions after rehearsal testing (P3c).

### 2.5 Why
- Only grants, RLS and database functions apply on **every** path (backend, direct API, n8n).
- Backend checks remain a second layer, as A1 requires.
- No standing super-credential exists in any network-facing component.

### 2.6 Dependencies
- **A1:** approved; this is consistent with it.
- **A5 / A9:** automation identity and actor model.
- **A3:** which functions exist.
- **A7:** audit inside functions.
- **A10:** migration role and environments.

### 2.7 Changes required (proposed)

| Area | Change |
|---|---|
| Database | Workflow functions; revoke direct client writes on workflow and audit tables; explicit grants for every table B uses, including those with no client access today (`services`, `device_tokens`, `notifications`, `recovery_checks`, `ai_analyses`); revoke `Dxtm` on new tables; review EXECUTE on trigger functions. |
| Backend | Port the auth/role middleware, zod, helmet and tests; replace direct table writes with `rpc(...)` calls; add authenticated machine endpoints; restrict CORS; add rate limiting. |
| n8n | No service_role or database URL; call backend machine endpoints only; block environment-variable access; HTTPS. |
| Mobile | Use Supabase Auth only to obtain a JWT; call the backend; hold no privileged keys. |

### 2.8 Questions for approval
- **A2-Q1:** Is any runtime service_role use permitted? If so, for which exact tasks, where is it stored, and who reviews it?
- **A2-Q2:** Should Flutter call Supabase directly for anything besides Auth (e.g. reads), or only the backend?
- **A2-Q3:** Remove direct client INSERT/UPDATE on `approvals`, `playbook_runs`, `remediation_executions`, `audit_logs`?
- **A2-Q4:** Secret store for the backend and n8n in each environment.

*(The n8n → backend authentication method is A5-Q3.)*

---

## 3. A3 – Approval & Remediation Workflow, and A4 – No-approval Playbook Rules

*Committed definitions: A3 – canonical approval authority and authorized approver roles. A4 – no-approval playbook execution rules. Status: both PENDING. This section also proposes, under A3, the lifecycle, execution, idempotency and failure rules that follow from a single approval authority.*

### 3.1 Current implementation (verified)
- **Two approval mechanisms [V-CODE]** (A3):
  - `approvals` (incident-level; decide = admin only; `B:controllers/approval.controller.ts:196-235`).
  - `playbook_runs` status/`approved_by` (decide = admin or operator; `B:controllers/playbook-run.controller.ts:264-299`).
  - Neither references the other. `approvals` has only `incident_id` [V-SCHEMA].
- **Lifecycle [V-CODE]:**
  - Run creation sets `pending_approval`, or **`approved`** if the playbook has `requires_approval = false` (`B:services/playbook-run.service.ts:57-60`) (A4).
  - The enabled check is in the backend only (`:39-41`).
  - The execute/status endpoint is **not routed** (`B:routes/playbook-run.routes.ts:30-32`).
  - Its transition map is `approved → running|cancelled`, `running → success|failed|cancelled` (`B:services/playbook-run.service.ts:173-180`).
- **Separation of duties:**
  - `approvals` UPDATE policy requires `requested_by <> auth.uid()` and `status = 'pending'` [V-LIVE, P7].
  - `playbook_runs` UPDATE requires `approved_by IS NULL OR approved_by <> requested_by` [V-LIVE].
  - No constraint `approver_id <> requested_by` [V-LIVE].
- **Deadlock [V-LIVE]:** pending approval `fdea11c4…` was requested by the only admin, so nobody can decide it.
- **Remediation [V-CODE]:** `remediation_executions` create/update are manager-only, with no approval lookup. Status and timestamps are client-supplied (`B:controllers/remediation-execution.controller.ts:60-104, 291-376`). Live execution `108d5a0d…` is `succeeded` while the incident's approval is pending and there are 0 recovery checks [V-LIVE].
- **Idempotency [V-SCHEMA/V-CODE]:**
  - No unique constraint preventing duplicate active runs per incident+playbook, and no idempotency key or external execution ID.
  - Decision and status updates use compare-and-set filters (`.eq("status", "pending_approval")`, `.eq("status", existingRun.status)`; `B:services/playbook-run.service.ts:141, 206`). This is a good pattern but applies to the backend path only.
- **Failure/cancellation:** statuses `failed`/`cancelled` exist [V-SCHEMA]. No timeout, retry or expiry handling exists [V-CODE]. Approval `cancelled`/`expired` statuses do not exist [V-SCHEMA].

### 3.2 Problems and risks
- Inconsistent approval authority (A3).
- Approvals not linked to the action they approve (A3).
- Auto-approval for any playbook with `requires_approval = false`, including the enabled "Test Restart Playbook" (restart action) [V-BACKUP] (A4).
- Remediation without approval (A3).
- No duplicate-execution protection (A3).
- No way out of a deadlocked or stale approval (A3).
- Possible direct pre-approved inserts (inference, not tested) (A3 with A2).

### 3.3 Alternatives

| Topic | Decision | Option 1 | Option 2 | Option 3 |
|---|---|---|---|---|
| Approval model | A3 | Keep both mechanisms | **`approvals` linked 1:1 to `playbook_runs` (authoritative); run status derived from it** | Approval fields only on `playbook_runs` (drop `approvals` usage) |
| Approver roles | A3 | Admin only | **Admin, plus operator for non-critical playbooks; never the requester** | Admin + operator for all |
| No-approval playbooks | **A4** | Auto-approve any | **Allowed only for explicitly non-protected action types; restart/rollback always protected** | Approval always required |
| Execution path | A3 | Backend only | **Database functions (`start_playbook_run`, `complete_playbook_run`) called by backend/n8n** | Direct table updates |
| Duplicate prevention | A3 | None | **Partial unique index (one active run per incident+playbook) + idempotency key + `n8n_execution_id` UNIQUE** | Backend locks only |

### 3.4 Recommendation [REC]
1. **(A3) One approval model.** `approvals.playbook_run_id` (FK, RESTRICT). At most one `pending` approval per run. The run can only reach `approved` through `decide_approval()`.
2. **(A3) Lifecycle (state machine, enforced by functions with compare-and-set):**
   - Run: `pending_approval → approved | rejected | cancelled`; `approved → running | cancelled`; `running → success | failed | cancelled`. Timeout → `failed` with a reason.
   - Approval: `pending → approved | rejected | cancelled (by requester) | expired`.
3. **(A3) Separation of duties:**
   - CHECK `approver_id <> requested_by`.
   - The decision function sets `approver_id = auth.uid()` itself.
   - Inserts must be `pending` with an empty approver.
   - Decided rows are immutable (trigger, including TRUNCATE guard).
4. **(A4) Protected playbooks:** a run is protected if `requires_approval = true` **or** its action type is in a protected set (proposed: restart, rollback). `approval_required` is copied onto the run when the run is created.
5. **(A3) Execution authorization:**
   - `start_playbook_run` requires: playbook enabled, protected ⇒ linked approval `approved`, run in `approved`, caller is an authorized human or the automation identity.
   - `complete_playbook_run` is automation-only (or operator manual override, decision A3-Q3).
6. **(A3) Idempotency:**
   - Partial unique index on active runs per (incident, playbook).
   - Client-supplied idempotency key on run requests.
   - `automation_runs.n8n_execution_id` UNIQUE.
   - All transitions via compare-and-set.
7. **(A3) Failure and cancellation:**
   - Explicit `failed` with an error payload.
   - Requester cancels pending; managers cancel approved or running.
   - Expiry of stale approvals.
   - A recovery check is required before the incident can be marked resolved (rule detail: U11).
8. **(A3, with A8) Legacy:** copy `remediation_executions` row `108d5a0d…` into `playbook_runs` with the same UUID and `legacy_source` set (mapping §2.9). Retire the remediation write endpoint.
9. **(A3) Deadlock:** resolved through approver-role policy (operator eligibility) or a second admin. The latter is a human decision; **no role is changed by migration**.

### 3.5 Why
- Removes both bypasses: the second approval path, and remediation without approval.
- Makes every decision attributable and final.
- Prevents duplicate execution and gives deterministic failure handling.

### 3.6 Dependencies
- **A2:** functions and grants.
- **A5 / A9:** automation and approver identities.
- **A7:** audit inside every transition.
- **A8:** columns and constraints added to existing tables.
- **A10:** rollout order.
- **A4 depends on A3** (protected runs require the A3 approval model).

### 3.7 Changes required (proposed)

| Area | Change |
|---|---|
| Database | `approvals.playbook_run_id`; new approval statuses; CHECK on approver; immutability trigger; partial unique index; idempotency column; workflow functions; recovery-check rule; protected action-type set (A4). |
| Backend | Call the functions; remove the separate run-decision path; route the execute step; remove client-supplied status and timestamps on remediation; return 403/409 instead of 500 on policy conflicts. |
| n8n | Executes only runs in `approved`, via a function; reports completion with its execution ID; never decides. |
| Mobile | Approval inbox shows only approvals the user may decide; requester can cancel; shows status changes in real time. |

### 3.8 Questions for approval
- **A3-Q1:** Who may decide approvals: admin only, or admin + operator (and for which playbooks)?
- **A3-Q2:** How should the existing deadlocked approval `fdea11c4…` be handled after the fix? (Human decision; not changed by migration.)
- **A3-Q3:** Can operators complete runs manually, or only n8n?
- **A3-Q4:** Approval expiry duration, and run timeout duration.
- **A4-Q1:** Which action types are always protected? Can `requires_approval = false` ever apply to restart/rollback?
- **A4-Q2:** What happens to the enabled, no-approval "Test Restart Playbook"? (Not changed by this report.)

---

## 4. A5 – n8n Automation Identity, A6 – Notifications Identity, and A9 – Actor Model

*Committed definitions: A5 – secure n8n integration identity and webhook authentication. A6 – notifications authentication and database compatibility. Status: both PENDING.*
*A9 – **PROPOSED NEW DECISION — NOT IN THE COMMITTED REGISTER — NOT APPROVED:** the general identity and actor-attribution model (user, operator, admin, system, AI) that A5 and A6 rely on.*

### 4.1 Current implementation (verified)
- **Roles [V-SCHEMA]:** `profiles.role` CHECK allows only `user`, `admin`, `operator`; new users default to `user` via `handle_new_user()`.
- **Role changes [V-LIVE/V-CODE]:** clients have no UPDATE on `profiles` (P3). Changes only via `admin_update_user_role()`, which blocks self-change and validates the role value.
- **Live identities [V-BACKUP]:** 2 profiles (1 admin, 1 operator), both email/password; no GitHub identities.
- **Actor columns [V-SCHEMA]:** `requested_by`, `approved_by`, `approver_id`, `triggered_by`, `created_by`, `actor_id`, `deployed_by` are all FKs to `profiles` (which itself references `auth.users`). There is **no** `actor_type` and no way to represent a non-human actor.
- **n8n (A5) [V-CODE]:** no n8n identity exists; no webhook verification code (`N8N_WEBHOOK_SECRET` is configured but unused).
- **Notifications (A6) [V-CODE]:**
  - The service takes `userId` from the request body (`notifications.routes.ts:9-14`).
  - It uses service_role (`supabase.service.ts:11,15`).
  - It writes `fcm_token`, `device_type`, `device_model`, `last_updated_at` and table `notifications_log`, which do not exist in the live schema (`supabase.service.ts:30-41, 84, 96-100`; live `device_tokens` has `device_token`, `platform` [V-SCHEMA]).
- **AI attribution (A9) [V-CODE]:** investigations accept client-supplied `ai_model` and results (`B:controllers/investigation.controller.ts:28-57`), so "AI" output is not attributable to a verified source.

### 4.2 Problems and risks
- Automated actions cannot be attributed (A5, A9).
- System-created records would need a fake human or NULL (A9).
- AI results can be submitted by any user (A9).
- Body-supplied user IDs (notifications) allow impersonation (A6).
- A machine identity with a human role (e.g. operator) could decide approvals (A5).
- Notifications writes would fail against the live schema (A6).

### 4.3 Alternatives

| Option | Applies to | For | Against |
|---|---|---|---|
| Use an operator account for n8n | A5 | No schema change | Can decide approvals; unattributable; violates separation |
| **Dedicated Supabase Auth user + new `automation` role value, restricted by RLS/EXECUTE** | A5 (and A6 if notifications stays a separate service) | Works with JWT + RLS (A1); attributable; revocable | Requires extending the role CHECK; credential storage and rotation |
| Custom PostgreSQL role connecting directly | A5 | Fine-grained grants | Needs `SUPABASE_DB_URL` in n8n; bypasses PostgREST and RLS-on-JWT design |
| `system` actor without auth (database-internal only) | A9 | For triggers and scheduled jobs | Not for external callers |
| Fold notifications into the backend | A6 | One authenticated surface; no separate credential | Larger backend |

### 4.4 Recommendation [REC]

| Actor type | Who | Authentication | May | May never | Decision |
|---|---|---|---|---|---|
| `user` | Human | Supabase JWT | Own incidents; request runs; cancel own requests | Decide approvals; change roles | A9 |
| `operator` | Human | Supabase JWT | Manage incidents and investigations; decide approvals per A3-Q1 (not own) | Change roles; manage playbooks | A9 / A3 |
| `admin` | Human | Supabase JWT | Everything administrative; decide approvals (not own); change others' roles via function | Change own role; approve own requests | A9 / A3 |
| `automation` (n8n) | Dedicated Auth user, role `automation` | Its JWT, presented to backend machine endpoints (plus request signing per A5-Q3) | Complete runs; record AI analysis; recovery checks; timeline events | Decide or create approvals; change roles; read audit | **A5** |
| notifications service | Same automation identity, or folded into the backend (A6-Q1) | Authenticated machine call | Send pushes; register tokens with the user ID from the JWT | Accept unauthenticated calls; use service_role | **A6** |
| `system` | Database itself (triggers, scheduled jobs) | Not externally callable | Expire approvals; time out runs; derived events | Anything requested by an external caller | A9 |
| `ai` | **Attribution label only** (model name/version on `ai_analyses`) | n/a (written by `automation`) | – | Act on its own; hold credentials | A9 |

1. **(A9) Every important record** carries `actor_type` + `actor_id` (the human or automation profile) and, for AI output, `ai_model`. `system` rows use `actor_type = 'system'` with `actor_id` NULL, allowed only for that type by a CHECK.
2. **(A9) Impersonation prevention:** actor IDs are always taken from `auth.uid()` inside functions, never from request bodies.
3. **(A9, A5) Role escalation prevention:**
   - Keep "no client UPDATE on `profiles`".
   - `automation` and `system` cannot be assigned through `admin_update_user_role()` by default (assignment procedure: A5-Q2).
   - Approval functions reject `automation`.
4. **(A6) Notifications:**
   - Authenticate every route.
   - Take the user ID from the JWT.
   - No service_role.
   - Align with `device_tokens`/`notifications`/`notification_deliveries` columns.

### 4.5 Why
Keeps A1's JWT + RLS model for machines too, makes every action attributable, and keeps humans as the only approvers.

### 4.6 Dependencies
- **A2:** machine authentication and grants.
- **A3:** approver roles.
- **A7:** actor columns on audit.
- **A8:** schema changes to the role CHECK and actor columns.

### 4.7 Changes required (proposed)

| Area | Change |
|---|---|
| Database | Extend the role CHECK with `automation` (A5); `actor_type` columns and CHECKs (A9); function role checks; `system`-only scheduled jobs (A9). |
| Backend | Machine endpoints accepting only the automation identity (A5); derive actors from the token; reject body-supplied user IDs (A6/A9). |
| n8n | Store the automation identity's credentials in its own encrypted credential store; rotate them (A5). |
| Notifications | Authentication, JWT-derived user ID, schema-aligned names, no service_role (A6). |
| Mobile | Show the actor type ("by n8n automation", "by system") in timelines (A9). |

### 4.8 Questions for approval
- **A5-Q1:** Approve a new role value `automation` (schema change to the `profiles.role` CHECK)?
- **A5-Q2:** Who may create or assign the automation identity, and how is it rotated or revoked?
- **A5-Q3:** n8n → backend authentication method: HMAC-signed requests with replay protection, the automation identity's JWT, or mTLS?
- **A6-Q1:** Fold notifications into the backend, or keep it as a separate service with machine authentication?
- **A9-Q1:** Is the `system` actor (scheduled expiry/timeouts) wanted? If so, which scheduler (e.g. pg_cron – availability **[UNKNOWN]**)?
- **A9-Q2:** Should AI results ever be accepted from human users (manual analysis), and how are they labelled?
- **A9-Q3:** GitHub sign-in with an existing email: link or reject (U10)?

---

## 5. A7 – Trusted Audit Logging & Incident History

*Committed definition: trusted audit logging (function-only writes; behaviour when an audit write fails). Status: PENDING. This section also proposes, as an extension of A7's scope, the incident timeline (`incident_events`), retention and redaction.*

### 5.1 Current implementation (verified)
- **Audit table [V-SCHEMA]:** `audit_logs` (24 rows) with `actor_id`, `action`, `entity_type`, `entity_id`, `details`, `created_at`. `details`/`created_at` are nullable but contain 0 NULLs [V-LIVE, P4].
- **Audit writes [V-CODE]:** written by the backend with the user's JWT, best-effort. Failures are swallowed (e.g. `B:controllers/approval.controller.ts:46-61`).
- **Audit access [V-LIVE]:** clients may INSERT with `actor_id = auth.uid()`; only admins can SELECT; no client UPDATE/DELETE grants or policies; no immutability trigger.
- **Actor FK [V-SCHEMA]:** `actor_id … ON DELETE SET NULL`, which rewrites audit rows when a profile is deleted.
- **Incident timeline:** `incident_logs` exists with 0 rows, unused by B [V-CODE]. `incident_events` (target) does not exist.
- **History gaps [V-BACKUP]:**
  - Audit starts 2026-11-03 17:13 UTC.
  - Creation of incident `6fc9b9e2…` is not audited.
  - Approvals and investigations are not audited.
- **Retention and redaction:** no policy exists **[UNKNOWN / not implemented]**. Audit `details` currently contain titles, summaries, IDs and role names; no email addresses were found in the 24 rows [V-BACKUP].

### 5.2 Problems and risks
- Forgeable entries (own identity).
- Silent gaps.
- Mutable by privileged roles, and TRUNCATE is not guarded.
- Profile deletion rewrites actor IDs.
- No timeline for users.
- No retention or redaction rules: risk of storing secrets or personal data in `details`/payloads.

### 5.3 Alternatives

| Option | For | Against |
|---|---|---|
| Single table for audit and timeline | Simple | Mixes security evidence with user-facing content; different access and retention |
| **Two tables: `audit_logs` (security, append-only, admin-read) + `incident_events` (timeline, per-incident read)** | Clear purposes and access | Two write paths, both through functions |
| External log sink only | Tamper-resistant | Extra infrastructure; harder joins |

### 5.4 Recommendation [REC]
1. **`audit_logs`:**
   - Written **only** inside trusted functions, in the same transaction as the action. If the audit write fails, the action fails.
   - No client INSERT.
   - Append-only trigger blocking UPDATE/DELETE (for all roles), plus a `BEFORE TRUNCATE` guard; TRUNCATE revoked from client roles.
   - Columns `actor_type`, `actor_id` (A9), `request_id`/`correlation_id`.
   - Actor FK → RESTRICT, or no FK with a stored actor reference (U8).
2. **`incident_events` (proposed A7 extension):** a user-facing timeline (status changes, investigation started/completed, approval requested/decided, run started/completed, recovery verified, comments).
   - Readable by whoever can read the incident; written by functions and the automation identity; append-only for clients.
3. **Historical gaps** are documented, **not** back-filled with invented entries. Back-filling `incident_events` from the existing audit rows is optional (U12; recommended: no).
4. **Retention (proposal):** audit kept for at least the project period and never deleted by applications. Timeline kept with the incident. Exact periods: a human decision.
5. **Redaction rules:** no secrets, tokens, passwords or full email addresses in `details`, payloads or timeline messages. Store IDs instead of personal data. Payload size limits. Integration secrets only in Vault.

### 5.5 Why
Makes audit evidence trustworthy and complete, gives users a timeline without exposing audit data, and prevents sensitive-data leakage.

### 5.6 Dependencies
- **A2:** trusted functions.
- **A9:** actor types.
- **A3:** events emitted by transitions.
- **A8:** new table and columns.
- **A10:** validation of the 24 existing rows.

### 5.7 Changes required (proposed)

| Area | Change |
|---|---|
| Database | `log_audit_event` (internal); append-only and TRUNCATE guards; actor columns; `incident_events` table and policies; indexes on `audit_logs(created_at, actor_id, entity_id)`. |
| Backend | Remove direct audit inserts and best-effort try/catch for required audit entries; add a correlation ID per request. |
| n8n | Writes timeline events through machine endpoints. |
| Mobile | Incident timeline view; no access to `audit_logs` except for admins. |

### 5.8 Questions for approval
- **A7-Q1:** Must an audit-write failure fail the action? (Recommended: yes.)
- **A7-Q2:** Retention periods for audit and timeline data.
- **A7-Q3:** Audit actor FK: RESTRICT or no FK (U8)?
- **A7-Q4:** Back-fill `incident_events` from existing audit rows (U12)?
- **A7-Q5:** Is an external, tamper-resistant audit sink required?
- **A7-Q6:** Accept the incident timeline, retention and redaction as part of A7's scope?

---

## 6. A8 – Existing Database Reconciliation

*A8 – **PROPOSED NEW DECISION — NOT IN THE COMMITTED REGISTER — NOT APPROVED.** Builds on `MIGRATION_MAPPING.md` and the open items U1, U6, U7, U8.*

### 6.1 Current implementation (verified)
- **Tables [V-SCHEMA]:** 18 live tables. 15 exist in the target; 3 are legacy (`incident_logs`, `audit_log`, `remediation_executions`); 3 target tables are missing (`incident_events`, `notification_deliveries`, `automation_runs`). Full mapping: `MIGRATION_MAPPING.md`.
- **Data [V-BACKUP, counts V-LIVE-matched]:** 46 rows in total, all in these 10 non-empty tables (2 + 2 + 3 + 4 + 5 + 1 + 1 + 24 + 3 + 1 = 46):
  - profiles 2, services 2, incidents 3, investigations 4, playbooks 5, playbook_runs 1, approvals 1, audit_logs 24, postmortems 3, remediation_executions 1.
  - All other tables have 0 rows.
- **Constraints [V-SCHEMA]:** CHECK constraints on status/severity/role values; UNIQUE on `profiles.email`, `playbooks.name`, `postmortems.incident_id`, `device_tokens.device_token`.
- **Foreign keys [V-SCHEMA]:** children of `incidents` use `ON DELETE CASCADE`; actor FKs use `SET NULL`; `playbook_runs.playbook_id` uses RESTRICT; `profiles.id → auth.users` CASCADE.
- **Indexes [V-SCHEMA]:** on most FK and status columns. **No index** on `approvals.incident_id`, `audit_logs` (`actor_id`, `created_at`, `entity_id`), `postmortems.incident_id` (covered by UNIQUE), `incidents.created_by`, `remediation_executions.playbook_id`/`triggered_by`.
- **Policies [V-LIVE, P7]:** 31 policies. **Grants [V-LIVE, P3]:** recorded baseline. **Functions [V-LIVE, P3c]:** 6. **Triggers [V-SCHEMA]:** `updated_at` on 6 tables, `on_auth_user_created` on `auth.users`, event trigger `ensure_rls`.
- **Schema source of truth [V-CODE]:**
  - `origin/feature/database:database/schema.sql` (last commit `12101a2`, 2026-10-27) defines **12 tables**. It lacks `approvals`, `investigations`, `audit_logs`, `remediation_executions`, `incident_logs` and `integrations` as tables. It also defines a `playbook_runs` `updated_at` trigger that the live database does not have.
  - `database/migrations/001_align_with_proposal.sql` (89 lines) renames and inserts playbooks and replaces `playbooks`/`ai_analyses` constraints.
  - **[INFERENCE]** 001 was applied to live: the live constraint names `playbooks_action_type_allowed`, `ai_analyses_*_allowed` and `ai_analyses_confidence_range`, and the playbook names, match it.
  - **[INFERENCE]** The other 6 live tables were created outside version control (e.g. in the SQL Editor).
- **Backup [V-BACKUP]:** pg_dump 18.6 custom format from PostgreSQL 17.11, without grants; **never test-restored**.

### 6.2 Problems and risks
- No complete, versioned schema that matches live (schema drift).
- Cascading deletes can destroy history.
- Duplicate or overlapping tables (`audit_log`/`audit_logs`, `remediation_executions`/`playbook_runs`, two approval mechanisms).
- Free-text `incidents.service_name` with no matching services [V-BACKUP].
- Backup without grants.
- Most data is test data, but it must not be discarded without a decision.

### 6.3 Alternatives

| Option | For | Against |
|---|---|---|
| Rebuild the schema from scratch and re-import | Clean | High risk of data and ID loss; breaks audit references |
| **Additive reconciliation in place (rehearsed on a restored copy)** | Keeps IDs and history; reversible stages | More steps; legacy tables live temporarily |
| Leave as is | No risk now | Leaves every gap open |

### 6.4 Recommendation [REC]
1. **Baseline first:** capture the live schema as migration `000_baseline` (from a schema-only dump including grants and policies). It becomes the single source of truth. Mark `schema.sql` and `001` as historical.
2. **Additive, staged changes** per `MIGRATION_EXECUTION_PLAN.md`: create the 3 missing tables; add nullable link columns; add statuses; then backfill; then constraints (`NOT VALID` → `VALIDATE`); then functions, triggers and RLS.
3. **Preservation:**
   - All 46 records keep their UUIDs. No row is deleted or rewritten.
   - `remediation_executions` row copied (not moved) with `legacy_source`.
   - Audit rows never modified.
   - Child FKs to incidents → RESTRICT, with soft delete (`archived_at`).
   - Legacy tables become read-only, then are renamed, and are dropped only after a separate approval.
4. **Add missing indexes** for audit queries and the new link columns.
5. **Test-data policy** is a human decision (keep, tag `is_test`, or archive). Never silently delete.

### 6.5 Why
Lowest risk of data loss, every stage reversible, and it creates the missing source of truth needed by A10.

### 6.6 Dependencies
- **A3, A7, A9:** they define the columns and constraints added.
- **A6:** notifications schema compatibility.
- **A10:** environments, baseline and rehearsal.

### 6.7 Changes required (proposed)

| Area | Change |
|---|---|
| Database | Baseline migration; 3 new tables; link columns; constraints; indexes; FK delete behaviour; legacy tables read-only. |
| Backend | Use `service_id` for incidents; stop writing `remediation_executions`; adapt to new columns. |
| n8n | Write `automation_runs` / `ai_analyses` (new or now-used tables). |
| Mobile | Show legacy/test markers if that policy is adopted. |

### 6.8 Questions for approval
- **A8-Q1:** Test-data policy: keep, tag, or archive?
- **A8-Q2:** Create real service records for "Payment Service" / "Test Service", or leave incidents unlinked (U6)?
- **A8-Q3:** Where does `remediation_executions` row `108d5a0d…` go: `playbook_runs` (recommended) or `automation_runs` (U1)?
- **A8-Q4:** Accept `000_baseline` from the live schema as the new source of truth, and treat `schema.sql`/`001` as historical?
- **A8-Q5:** Approve soft delete (`archived_at`) instead of hard delete for incidents?

---

## 7. A10 – Migration & Deployment Strategy

*A10 – **PROPOSED NEW DECISION — NOT IN THE COMMITTED REGISTER — NOT APPROVED.** Builds on `MIGRATION_EXECUTION_PLAN.md` stages 0–13 and open item U13 (migration execution method).*

### 7.1 Current implementation (verified)
- **Plan [V-CODE]:** `MIGRATION_EXECUTION_PLAN.md` defines stages 0–13 with gates; no stage has been executed.
- **Environments:**
  - Only one Supabase project is known (`hjqvjztbsndgyooyadup`).
  - Whether separate dev/test/staging projects or Supabase branching exist: **[UNKNOWN]**.
  - The live database contains mostly test data [V-BACKUP] but is treated as production in this plan.
- **Execution identity:** SQL Editor runs as `postgres` [V-LIVE, P3d]; Supabase CLI identity **pending/[UNKNOWN]**.
- **Migrations in the repo [V-CODE]:** only `origin/feature/database:database/migrations/001_align_with_proposal.sql`. There is no `supabase/` folder or `config.toml` in any branch, so there is no CLI migration setup.
- **Backup [V-BACKUP]:** one custom-format backup (2026-11-07), without grants and **not test-restored**. Point-in-time recovery availability: **[UNKNOWN]** (plan-dependent).
- **CI/CD [V-CODE]:** no deployment pipeline or migration automation found in the repository.

### 7.2 Problems and risks
- No proven restore.
- No separate rehearsal environment confirmed.
- No migration tooling or version history matching live.
- Grants missing from backups.
- Execution identity not fixed.
- No deployment approval trail.

### 7.3 Alternatives

| Option | For | Against |
|---|---|---|
| Manual SQL in the SQL Editor on production | Fast | Unrepeatable; error-prone; no review trail |
| **Versioned migrations (Supabase CLI or equivalent) applied first to a separate project or branch, then production, with gates** | Repeatable; reviewable; rehearsed | Setup effort |
| Full rebuild in a new project and cut-over | Clean target | Data copy and ID preservation risk; Auth migration complexity |

### 7.4 Recommendation [REC]
1. **Environments:** at least **two separate Supabase projects** (or Supabase branching, if available): `dev/test` (rehearsal from restored backups) and `production`. Never rehearse on production.
2. **Source control:** `000_baseline` + numbered migrations in one repository folder, reviewed by pull request. Each migration is additive or has a documented, tested reverse.
3. **Execution identity:** one fixed method, decided by the team (SQL Editor as `postgres`, or CLI with a verified identity). The identity is recorded with every applied migration.
4. **Backup and restore:**
   - Before every production stage: custom-format dump plus a **separate roles/grants dump**, with a hash recorded.
   - Test-restore into the rehearsal project.
   - Compare row counts and per-table checksums (checklist P1/P2).
5. **Sequence:** stages 0–13 of the existing plan, with stage 0 = approval of the architecture decisions.
6. **Validation:**
   - **Pre-migration:** P1–P4, P3b–P3d, P7 baselines.
   - **Post-migration:** re-run all, check the 46 records (§D), workflow tests (stage 9), auth matrix (stage 8).
7. **Rollback:** Level 1 app revert, Level 2 policy restore, Level 3 data restore. Timed in rehearsal. Triggers for rollback defined in advance.
8. **Deployment approval and audit:**
   - Owner sign-off per stage.
   - A migration log (who, when, which identity, which hash).
   - Maintenance window with n8n paused.
   - No production change without a passed rehearsal.

### 7.5 Why
Turns a single, unversioned live database into a reproducible, reviewable system with a proven way back.

### 7.6 Dependencies
- **All other decisions:** A10 executes them.
- **A8:** baseline.
- **A2:** grants.
- **A5:** automation identity provisioning per environment.

### 7.7 Changes required (proposed)

| Area | Change |
|---|---|
| Database | Baseline + versioned migrations; separate rehearsal project; grants captured in backups. |
| Backend | Environment-specific configuration; no shared secrets between environments. |
| n8n | Separate instance or credentials per environment; paused during migrations. |
| Mobile | Build flavours pointing at the right backend per environment. |

### 7.8 Questions for approval
- **A10-Q1:** Is a separate Supabase project (or branching) available for rehearsal? Plan/cost: **[UNKNOWN]**.
- **A10-Q2:** Migration execution method: SQL Editor or Supabase CLI (U13)?
- **A10-Q3:** Is point-in-time recovery available on the current plan?
- **A10-Q4:** Who approves each production stage, and where is the migration log kept?
- **A10-Q5:** Maintenance-window and user-communication requirements.

---

## 8. Recommended final architecture (proposed)

```
Flutter app ──(Supabase Auth: email/GitHub → user JWT)──► Backend API (Express, base B + ported middleware)
                                                          │  verifies JWT, profile, role; zod validation
                                                          │  user JWT forwarded ▼
n8n ──(automation identity JWT + signed request)────────► Backend machine endpoints            [A5]
                                                          │
                                                          ▼
                                   Supabase PostgreSQL (authoritative enforcement)             [A2]
                                   • RLS + explicit grants (no client writes to workflow/audit tables)
                                   • SECURITY DEFINER workflow functions (role checks inside, search_path='')  [A2, A3, A4]
                                   • Triggers: immutable approvals, append-only audit, TRUNCATE guards         [A3, A7]
                                   • audit_logs (trusted) + incident_events (timeline)                         [A7]
Notifications service ◄──(authenticated machine call from backend/n8n)── no service_role       [A6]
service_role: none at runtime; optional isolated Auth-admin module only (A2-Q1)
```

| Component | Responsibilities | Must never |
|---|---|---|
| **Flutter** | Sign in via Supabase Auth; call the backend with the JWT; display data and timeline. | Hold service_role or machine credentials; write workflow tables directly. |
| **Backend** | Verify JWT, profile and role; validate input; forward the user JWT; call workflow functions; machine endpoints for n8n; CORS, helmet, rate limiting. | Use service_role for user requests; be the only enforcement of a workflow rule. |
| **n8n** | Investigation, execution, recovery and notification workflows via machine endpoints, as the automation identity. | Decide approvals; hold service_role or the database URL; read all environment variables. |
| **PostgreSQL** | RLS, grants, constraints, functions, triggers, audit and timeline. | Trust any caller-supplied actor ID. |
| **Notifications** | Send pushes on authenticated machine calls; register tokens with the user ID from the JWT. | Accept unauthenticated calls; use service_role. |

---

## 9. Cross-decision review

### 9.1 Conflicts with A1
**None found.** All recommendations keep:
- user JWT + RLS as the primary model;
- backend checks as an additional layer;
- no service_role in Flutter or n8n;
- dedicated limited identities for automation.

A2 option D (isolated service_role) is the only point that needs care; it is optional and excluded from Flutter and n8n, consistent with A1's "carefully controlled and explicitly authorized mechanism".

### 9.2 Conflicts between decisions

| Potential conflict | Resolution |
|---|---|
| A3 "immutable decisions" vs A8 "copy legacy remediation row" | Copy before the immutability and guard triggers exist (A10 stage order), or let them accept rows flagged `legacy_source`. |
| A7 "append-only audit" vs FK `ON DELETE SET NULL` on `actor_id` | Change to RESTRICT or remove the FK (A7-Q3) before enabling the append-only trigger. |
| A5 new `automation` role vs `admin_update_user_role()` allowed values | Keep the function's allowed values human-only; provision automation through a separate, controlled procedure (A5-Q2). |
| A2 "revoke direct client writes" vs current B code (direct inserts) | The backend must switch to `rpc(...)` in the same release as the grant changes (A10 sequencing). |
| A3 "operator may decide" vs current `approvals` RLS (admin-only SELECT/UPDATE) | Policies change in A2/A3 together. |
| A10 "rehearsal environment" vs only one known project | Blocks A10 until A10-Q1 is answered. |
| A7 scope extension (timeline, retention) vs committed A7 definition (audit only) | Needs explicit acceptance (A7-Q6); the committed definition is not changed by this report. |

### 9.3 Dependency matrix (row depends on column)

| | A1 | A2 | A3 | A4 | A5 | A6 | A7 | A8* | A9* | A10* |
|---|---|---|---|---|---|---|---|---|---|---|
| **A2** Security boundary | ● | – | ○ | ○ | ● | ○ | ○ | ○ | ● | ○ |
| **A3** Approval workflow | ● | ● | – | ● | ○ | ○ | ○ | ● | ● | ○ |
| **A4** No-approval rules | ● | ○ | ● | – | ○ | – | ○ | ○ | ○ | ○ |
| **A5** n8n identity | ● | ● | ○ | – | – | ○ | ○ | ○ | ● | ○ |
| **A6** Notifications | ● | ● | ○ | – | ○ | – | ○ | ● | ● | ○ |
| **A7** Audit & history | ● | ● | ○ | – | ○ | – | – | ● | ● | ○ |
| **A8\*** Reconciliation | ● | ○ | ● | ○ | ○ | ○ | ● | – | ● | ● |
| **A9\*** Actor model | ● | ● | ○ | – | ○ | ○ | ○ | ○ | – | ○ |
| **A10\*** Migration | ● | ● | ● | ● | ● | ● | ● | ● | ● | – |

● strong dependency · ○ weak or informational · \* proposed new decision — not in the committed register — not approved

### 9.4 Proposed approval order
1. **A8\*** – agree what exists and the preservation rules (facts first; the baseline is needed by everything).
2. **A9\*** – define the actor model (A2, A3, A5, A6 and A7 all reference it).
3. **A2** – the security boundary built on those actors.
4. **A5** – the n8n machine identity within that boundary.
5. **A6** – the notifications identity and compatibility.
6. **A3** – the approval workflow on top of the boundary.
7. **A4** – no-approval rules, which depend on the A3 model.
8. **A7** – audit and timeline, emitted by the A3 functions.
9. **A10\*** – how to execute all of the above safely.

If A8–A10 are not accepted into the register (Q-X1), their content remains as supporting analysis for A2–A7 and the existing migration plan.

---

## 10. Impact matrix

| Decision | Database | Backend | n8n | Mobile |
|---|---|---|---|---|
| **A2** | Functions; revoke client workflow writes; explicit grants; Dxtm/EXECUTE hygiene | Port middleware; rpc calls; machine endpoints; CORS/rate limit | No service_role/DB URL; env access blocked; HTTPS | JWT only; no privileged keys |
| **A3** | Approval link; statuses; CHECKs; immutability; unique active run; idempotency; workflow functions | Single approval path; execute route; remove client-set status/timestamps | Execute only approved runs; report with execution ID | Approval inbox; cancel; live status |
| **A4** | Protected action-type set; `approval_required` copied onto each run | Remove auto-approval path | – | Show protected/unprotected playbooks |
| **A5** | `automation` role; machine-function EXECUTE grants | Machine endpoints; request signing | Credential storage and rotation; no service_role | – |
| **A6** | Grants/policies for `device_tokens`, `notifications`, `notification_deliveries` | Authenticated notification calls (or fold in) | Authenticated calls to notifications | Token registration via JWT |
| **A7** | Trusted audit function; append-only + TRUNCATE guard; actor columns; `incident_events` | Remove best-effort audit; correlation IDs | Timeline events via endpoints | Timeline view |
| **A8\*** | Baseline; 3 new tables; link columns; FK RESTRICT; indexes; legacy read-only | `service_id`; stop legacy writes | Use `automation_runs`/`ai_analyses` | Test/legacy markers (if adopted) |
| **A9\*** | `actor_type`; function role checks; `system` jobs | No body-supplied IDs | – | Actor labels |
| **A10\*** | Versioned migrations; rehearsal project; grants in backups | Per-environment config | Per-environment instance/credentials; pause during migration | Build flavours |

---

## 11. Data preservation and security risks

### 11.1 Data preservation (must hold for every decision)
- All 46 existing records (per-table counts in §6.1) are preserved with their UUIDs. No deletes, overwrites or silent skips.
- Audit rows are never modified; historical gaps are documented, not invented.
- The pending approval `fdea11c4…` stays pending; the pending run `e48ca6e7…` stays unchanged; no role is changed; no playbook is enabled or disabled.
- Legacy tables are retained read-only until a separate approval.
- New constraints apply to new writes where existing history would violate them (e.g. postmortems on unresolved incidents).

### 11.2 Security risks (current, until decisions are implemented)

| Risk | Status | Addressed by |
|---|---|---|
| Possible direct approval / pre-approved run inserts | Inference, not tested | A2, A3 |
| Remediation without approval | Verified (code) | A3 |
| Two inconsistent approval authorities | Verified (code) | A3 |
| Auto-approval of runs for no-approval playbooks | Verified (code) | A4 |
| Forgeable and silently missing audit entries | Verified (live + code) | A7 |
| Notifications: service_role + no authentication | Verified (code) | A6 (with A2) |
| Planned n8n env with service_role/DB URL; env access not blocked | Verified (config template) | A5 (with A2) |
| Unattributable automated/AI actions | Verified (schema + code) | A9\*, A5 |
| History destroyed by cascades | Verified (schema) | A8\* |
| Backup not restorable-proven; no grants in backup | Verified | A10\* |
| No versioned schema matching live | Verified (code) + inference | A8\*, A10\* |
| Inherited TRUNCATE on new tables | Verified (live default ACL) | A2 |

---

## 12. Open questions requiring team decisions

| # | Question |
|---|---|
| Q-X1 | Accept A8 (database reconciliation), A9 (actor model) and A10 (migration & deployment) as new decisions in the Phase 19 register, and approve any additional implementation gates they introduce? (The A7 scope extension is asked separately as A7-Q6.) |
| A2-Q1 | Any runtime service_role use permitted? For what, where stored, who reviews? |
| A2-Q2 | Flutter direct Supabase access beyond Auth: yes/no? |
| A2-Q3 | Revoke direct client writes on `approvals`, `playbook_runs`, `remediation_executions`, `audit_logs`? |
| A2-Q4 | Secret store per environment? |
| A3-Q1 | Approver roles: admin only, or admin + operator (for which playbooks)? |
| A3-Q2 | Handling of the deadlocked approval `fdea11c4…` after the fix? |
| A3-Q3 | Manual run completion by operators allowed? |
| A3-Q4 | Approval expiry and run timeout durations? |
| A4-Q1 | Always-protected action types? |
| A4-Q2 | Fate of the enabled no-approval "Test Restart Playbook"? |
| A5-Q1 | New `automation` role value? |
| A5-Q2 | Who provisions, rotates and revokes the automation identity? |
| A5-Q3 | n8n → backend authentication method (HMAC with replay protection / automation JWT / mTLS)? |
| A6-Q1 | Fold notifications into the backend, or keep a separate authenticated service? |
| A7-Q1 | Must audit failure fail the action? |
| A7-Q2 | Retention periods? |
| A7-Q3 | Audit actor FK: RESTRICT or none? |
| A7-Q4 | Back-fill `incident_events` from audit? |
| A7-Q5 | External tamper-resistant audit sink required? |
| A7-Q6 | Accept the timeline/retention/redaction scope extension of A7? |
| A8-Q1 | Test-data policy: keep / tag / archive? |
| A8-Q2 | Create real services for free-text service names, or leave unlinked? |
| A8-Q3 | Target for remediation row `108d5a0d…`? |
| A8-Q4 | Accept `000_baseline` from live as the source of truth? |
| A8-Q5 | Soft delete for incidents? |
| A9-Q1 | `system` actor and scheduler (pg_cron availability unknown)? |
| A9-Q2 | Human-entered AI analysis allowed, and how labelled? |
| A9-Q3 | GitHub sign-in with an existing email: link or reject? |
| A10-Q1 | Separate rehearsal project or branching available? |
| A10-Q2 | Migration method: SQL Editor or CLI? |
| A10-Q3 | Point-in-time recovery available? |
| A10-Q4 | Stage approvers and migration log location? |
| A10-Q5 | Maintenance-window and communication requirements? |

Earlier open items that remain relevant: U2, U6, U8, U10, U11, U12, U13 (see `MIGRATION_EXECUTION_PLAN.md`).

---

## 13. Recommended implementation sequence (after approval only)

1. **Approve** A8\* → A9\* → A2 → A5 → A6 → A3 → A4 → A7 → A10\* (§9.4), and resolve Q-X1.
2. **Prepare environments** (A10\*): rehearsal project, fresh backup + grants dump, proven test restore, baseline migration `000_baseline` (A8\*).
3. **Backend groundwork** (A1/A2, no database change): port the middleware, zod, helmet and tests into the base branch; add the machine-endpoint skeleton (A5); fix `package.json`. *(Application change; separate approval and review.)*
4. **Database stages 3–5 on rehearsal:** new tables, link and actor columns, statuses, indexes, FK changes, legacy row copy (A8\*, A3, A7, A9\*).
5. **Database stage 6 on rehearsal:** workflow functions, protected-playbook rules, immutability, append-only and TRUNCATE guards, the trusted audit function (A2, A3, A4, A7).
6. **Database stage 7 on rehearsal:** explicit grants and policies; revoke direct workflow writes; EXECUTE hygiene; automation identity; notifications access (A2, A5, A6).
7. **Switch the backend to the functions** in the same release as stage 7 (§9.2).
8. **Tests on rehearsal:** auth matrix, workflow scenarios, n8n end-to-end, record validation (stages 8–11).
9. **Rollback rehearsal**, timed (stage 12).
10. **Production migration** with owner sign-off, maintenance window and migration log (stage 13).

---

*This report is read-only analysis. A1 is APPROVED; A2–A7 are PROPOSED / PENDING APPROVAL; A8–A10 are PROPOSED NEW DECISIONS — NOT IN THE COMMITTED REGISTER — NOT APPROVED. Nothing described here has been implemented.*
