# Complete Database Implementation Roadmap

**Project:** AI-Powered Mobile DevOps Command Center
**Phase:** 1 – Complete database audit and implementation roadmap
**Date:** 2026-11-07
**Branch:** `feature/database-implementation` (= `origin/feature/backend-api-database` @ `84fb81a` + 1 commit `d01017a`, root `.gitignore`)

**Decision status (nothing below changes it):**
- **A1 – APPROVED** (2026-11-07): hybrid; base `origin/feature/backend-api-database`; user JWT + RLS primary; backend checks as a second layer; service_role never in Flutter or n8n.
- **A2–A7 – PENDING.**
- **A8–A10 – PROPOSED, not in the committed register, not approved.**
- **R1–R12 – new questions raised by this audit (§4.4).** Decision Batch 1 (2026-11-07) decided R1, R2, R7, R12 and A2-Q1 (D-001 to D-005 in `database/DATABASE_DECISION_REGISTER.md`). A2 as a whole stays PENDING. The other R-items remain open.

> ## ⛔ IMPLEMENTATION BLOCKER (unchanged)
> **No migration SQL or live database changes until all required decisions in the committed A2–A7 register have been approved.**

This document plans; it does not implement. While preparing it, no SQL was executed, Supabase was not contacted, and no application code, migration, environment file or existing document was changed.

### Evidence labels

| Label | Meaning |
|---|---|
| **[V]** | Verified in this audit from the repository or the local schema export (read-only). |
| **[R]** | Live-database fact recorded in the committed Phase 19 documents (not re-checked here; this audit does not connect to Supabase). |
| **[A]** | Assumption or inference. Must be verified. |
| **[Rec]** | Recommendation. **Not approved.** |
| **[DEC]** | Needs a team decision before work can proceed. |

---

## 1. Sources inspected

| Area | Source | Notes |
|---|---|---|
| Phase 19 documents | `feature/backend-api:database/` – `PHASE19_FINAL_VERIFICATION_REPORT.md`, `MIGRATION_MAPPING.md`, `MIGRATION_EXECUTION_PLAN.md`, `SECURITY_AND_DATA_PRESERVATION_CHECKLIST.md`, `A2_A7_ARCHITECTURE_DECISION_REPORT.md` (commit `030df62`) | **Not present on this branch** [V]; read with `git show`. |
| A2–A7 review | `database/A2_A7_REVIEW_2026-11-07.md` | **Does not exist on any branch** [V]. Its findings were delivered in chat only; they are carried into this roadmap (§3, §4.4) and labelled as review findings. |
| Live schema (structure only) | `../database-backups/public-schema.sql` (outside the repository, 1,480 lines) | Read for tables, constraints, FKs, indexes, policies, functions, triggers [V]. No data read. The data backup (`.dump`) was **not** opened. |
| Backend | This branch: `backend/src/` (11 controllers, 11 routes, 11 services, `config/supabase.ts`, `middleware/auth.ts`), `backend/package.json` | [V] |
| A1 port source | `feature/backend-api:backend/src/` (`middleware/auth.ts`, `lib/supabase.ts`, `routes/auth.routes.ts`) | [V] |
| SQL / migrations | `origin/feature/database:database/schema.sql` (12 tables), `database/migrations/001_align_with_proposal.sql` | Only SQL in any branch [V]. No `supabase/` folder or `config.toml` anywhere [V]. |
| n8n | `origin/feature/n8n-incident-workflow` (`a0c7569`): `automation/docker-compose.yml`, `automation/schemas/ai-output.schema.json`, `automation/prompts/`, `.env.example` (variable **names** only) | `automation/workflows/` holds only `.gitkeep` [V]. |
| Notifications | `origin/feature/notifications` | **Force-updated on 2026-11-07** back to `9aa3a0d` (README only). Earlier code `43c9747` is on no branch [V]. |
| Mobile | `origin/feature/mobile-ui` (`8c72c31`, 28 screens) | UI only. `pubspec.yaml` has no Supabase or HTTP package; there is no data layer [V]. |
| Other branches | `main`, `dev`, `feature/ai-investigation`, `feature/integration-testing`, `feature/monitoring`, `feature/notifications` = `9aa3a0d` (initial structure); `feature/repo-setup` = README files only | [V] |

---

## 2. Audit summary

### 2.1 Database (live) – current state

| Item | Current state | Evidence |
|---|---|---|
| Tables | 18 `public` tables. 15 match the approved 18-table target. 3 are legacy (`incident_logs`, `audit_log`, `remediation_executions`). 3 target tables are missing (`incident_events`, `notification_deliveries`, `automation_runs`). | [V] export; [R] |
| Data | 46 rows in 10 tables: profiles 2, services 2, incidents 3, investigations 4, playbooks 5, playbook_runs 1, approvals 1, audit_logs 24, postmortems 3, remediation_executions 1. | [R] |
| RLS | Enabled on all 18 tables. 31 permissive policies on 12 tables. | [V] |
| Tables with **no** policy | `ai_analyses`, `audit_log`, `deployments`, `notifications`, `recovery_checks`, `services` → no client access at all. | [V] |
| Grants (`authenticated`) | approvals I/S/U · audit_logs I/S · incident_logs I/S · incidents I/S/U · integrations D/I/S/U · investigations I/S/U · playbook_runs I/S/U · playbooks D/I/S/U · postmortems I/S/U · profiles S · remediation_executions I/S/U. No grant on the other 7 tables. `anon`: none. | [R] P3 |
| Default ACL (objects created by `postgres`) | New tables give `anon`/`authenticated` TRUNCATE, REFERENCES, TRIGGER, MAINTAIN (`Dxtm`). New functions are `postgres`-only. | [R] P3b |
| Functions | `admin_update_user_role` (SECURITY DEFINER, `search_path=''`, blocks self-change, allows only user/admin/operator), `is_admin`, `is_incident_manager`, `handle_new_user`, `rls_auto_enable`, `set_updated_at`. | [V] |
| Triggers | `updated_at` on device_tokens, incidents, playbooks, postmortems, profiles, services. **None on workflow or audit tables.** | [V] |
| Value sets | playbook `action_type`: restart, rollback, scale, circuit_breaker. Run status: pending_approval, approved, running, success, failed, rejected, cancelled. Approval status: pending, approved, rejected. Notification channel: in_app, push, email, telegram. Role: user, admin, operator. | [V] |
| FK delete behaviour | All children of `incidents` → CASCADE. Actor FKs → SET NULL. `playbook_runs.playbook_id` → RESTRICT. `profiles.id → auth.users` → CASCADE. | [V] |
| Missing indexes | `approvals.incident_id`, `audit_logs(actor_id, created_at, entity_id)`, `incidents.created_by`, `remediation_executions.playbook_id/triggered_by`, `approvals.requested_by/approver_id`. | [V] |
| Backup | One custom-format dump, without grants, **never test-restored**. | [R] |
| Source of truth | No versioned schema matches live. `schema.sql` defines only 12 tables. `001` was probably applied [A]. Six tables were created outside version control [A]. | [V]/[A] |

### 2.2 Backend (this branch, the A1 base)

- **Auth:** `supabase.auth.getUser(token)` with the publishable key, then a per-request client carrying the user's JWT (`backend/src/middleware/auth.ts:41,57`; `backend/src/config/supabase.ts`) [V]. **No service_role** in `backend/src` [V].
- **Tables used:** incidents (13 calls), playbook_runs 6, playbooks 5, approvals 4, integrations 4, investigations 4, postmortems 4, remediation_executions 4, audit_logs 2, profiles 2. One RPC: `admin_update_user_role` [V].
- **Not used by the backend:** services, deployments, ai_analyses, recovery_checks, notifications, device_tokens, incident_logs [V].
- **Workflow gaps** [V]:
  - Two approval paths: `approvals` (decided by admin only) and `playbook_runs` (decided by admin or operator).
  - Auto-approval when `requires_approval = false` (`backend/src/services/playbook-run.service.ts:55-59`).
  - The execute/status endpoint is imported but **not routed** (`backend/src/routes/playbook-run.routes.ts`).
  - Remediation has no approval check, and its update path accepts client-supplied `status`, `started_at` and `completed_at`.
- **Audit:** best-effort; failures are caught and only logged (e.g. `backend/src/controllers/approval.controller.ts:45-59`) [V].
- **Incidents:** the backend writes free-text `service_name` and `environment`, never `service_id` [V].
- **Tooling:** `package.json` has no test script and no validation library, and declares `"type": "commonjs"` while the source imports `.js`-suffixed ESM paths. It runs through `tsx` [V].

### 2.3 Other components

- **n8n** [V]:
  - No workflows exist.
  - `docker-compose.yml`: image `:latest`, `N8N_PROTOCOL: "http"`, `N8N_BLOCK_ENV_ACCESS_IN_NODE: "false"`.
  - `.env.example` lists `SUPABASE_SERVICE_ROLE_KEY` and `SUPABASE_DB_URL`. `N8N_WEBHOOK_SECRET` is listed but unused.
  - The AI output schema (summary, severity low–critical, evidence[], confidence, recommended_action in restart/rollback/scale/circuit_breaker) matches the `ai_analyses` columns and checks. It has no `root_cause` field.
- **Notifications** [V]: no current code on any branch. The last known snapshot (`43c9747`):
  - had no route authentication and CORS open to all origins;
  - took `userId` from the request body;
  - used service_role;
  - wrote columns and tables that don't exist (`fcm_token`, `notifications_log`).
- **Mobile** [V]:
  - UI only, with no Supabase or HTTP dependency.
  - Several screens have **no backing table**: s09 logs explorer, s10 metrics, s13 repositories, s15 failed pipeline job, s23 developer assistant, s24 pull request summary, s27 notification preferences.
  - s27 offers channels Push, Email, Slack and Discord; the live `notifications.channel` check allows in_app, push, email, telegram.

---

## 3. Conflicts found (before any change is proposed)

| # | Conflict | Evidence | Impact | Resolved by |
|---|---|---|---|---|
| C1 | The middleware A1 says to port (`feature/backend-api`) checks tokens and reads `profiles` through a **service_role** client (`middleware/auth.ts:2,28,39`; `lib/supabase.ts:7,15-17`). | [V] | Porting it as-is puts service_role into every request, conflicting with the A2 direction. | A2-Q1, R7 |
| C2 | Two approval authorities with different approver roles. | [V] | Inconsistent decisions; bypass through the weaker path. | A3 |
| C3 | Remediation executes without an approval check; status and timestamps are client-set. | [V] | Unapproved "succeeded" execution exists [R]. | A3 |
| C4 | Auto-approval for no-approval playbooks. All 4 allowed action types change production state. | [V] | Restart can run with no human check. | A4, R8 |
| C5 | Rules exist only in the backend; direct Supabase API calls with a user JWT may skip them. | [A] not tested | Workflow bypass. | A2 |
| C6 | The `profiles_update_own` policy has no column restriction; only the missing UPDATE grant prevents self-role-change. | [V] policy; [R] grant | A future broad `GRANT UPDATE ON profiles` would allow self-escalation. | A2 (precaution) |
| C7 | The backend uses free-text `incidents.service_name`; the target model links incidents with `service_id`. | [V] | Service screens and joins can't work. | U6, R10 |
| C8 | The backend doesn't use `services`, `deployments`, `ai_analyses` or `recovery_checks` (no grants either), but the mobile screens and n8n need them. | [V] | Missing read paths. | A2-Q2, R3, R5 |
| C9 | The mobile notification channels (Slack, Discord) don't match the database check (in_app, push, email, telegram). There is no preferences table. | [V] | s27 can't be stored. | R4 |
| C10 | Notifications code was removed from its branch; the A6 evidence is a snapshot. | [V] | A6 can't be approved on current code. | R6 |
| C11 | `schema.sql` (12 tables) and `001` don't match live (18 tables). `schema.sql` defines a `playbook_runs` `updated_at` trigger, but that table has no `updated_at` column live. | [V] | No reliable source of truth. | A8, R2 |
| C12 | The Phase 19 documents and `001` live on other branches, not on this implementation branch. | [V] | The implementation branch has no plan or migration history. | R1 |
| C13 | Append-only audit and a RESTRICT actor FK vs `profiles → auth.users` CASCADE. | [V] | Deleting a user in Supabase Auth would fail, or audit would be rewritten. | A7-Q3, U8 |
| C14 | Immutability and approval-required triggers vs the copy of legacy remediation row `108d5a0d…`. | [R] mapping §2.9 | The copy is rejected if the triggers exist first. | Ordering (Phase 8 before Phase 10) |
| C15 | Revoking direct client writes vs current backend direct inserts. | [V] | The app breaks unless both ship together. | Phase 11 |
| C16 | The A3 "live status in the app" goal needs direct Supabase Realtime reads vs A2-Q2 ("backend only?"). | report | Design conflict. | A2-Q2, R5 |
| C17 | Severity sets differ: `incidents` allows `info`; `ai_analyses` and the n8n schema don't. The AI output has no `root_cause` although `ai_analyses` has one. | [V] | Mapping ambiguity. | R11 |
| C18 | The A4 report wording says "allow-list" in the summary but uses a "block-list" (restart/rollback) in the detail. | report | New action types may be unprotected. | R8 / A4-Q3 |
| C19 | Dashboard counts run under the user JWT, so a `user` sees only their own incidents. | [V] code + policies | Different dashboards per role (possibly intended). | A2-Q2 (confirm) |

---

## 4. Decision reconciliation

### 4.1 Approved
| # | Decision |
|---|---|
| A1 | Hybrid backend: base `origin/feature/backend-api-database`; user JWT + RLS primary; port auth/role middleware, zod, helmet, Vitest/Supertest and password reset from `feature/backend-api`; service_role never in Flutter or n8n. **Note C1:** the port must be adapted to the user-JWT client. |

### 4.2 Pending (committed register) – must be approved before any SQL

| # | Committed definition | Report's recommended option [Rec] | Key open questions |
|---|---|---|---|
| A2 | User-token/RLS vs service-role; privileged mechanism; final grant/RLS boundary | JWT + RLS; narrow SECURITY DEFINER functions for workflow-critical writes; revoke direct client writes on workflow and audit tables; no runtime service_role | A2-Q1…Q4; review: trigger-based enforcement (Q5), middleware port (Q6) |
| A3 | Approval authority and approver roles | `approvals.playbook_run_id` (1:1); state machine in functions; requester ≠ approver; immutable decisions; idempotency; retire `remediation_executions` writes | A3-Q1…Q4, U2, U3, U11; review: legacy approval with no run, 2-person approval, n8n trigger step |
| A4 | No-approval execution rules | Protected if `requires_approval` **or** action type is protected; `approval_required` copied onto the run | A4-Q1, A4-Q2, U4, U5; R8 allow-list vs block-list; who may switch off approval |
| A5 | n8n identity and webhook authentication | Dedicated Supabase Auth user with an `automation` role; backend machine endpoints; never service_role or DB URL | A5-Q1…Q3, U9; review: who holds the credential; backend → n8n webhook signing |
| A6 | Notifications authentication and database compatibility | Authenticated machine calls; user ID from JWT; no service_role; schema-aligned names | A6-Q1; R6 (where is the code?); who may notify other users |
| A7 | Trusted audit (function-only writes; failure behaviour) | Audit inside functions, same transaction, fail closed; append-only + TRUNCATE guard; separate `incident_events` timeline (scope extension) | A7-Q1…Q6, U8, U12; review: triggers for direct writes; reuse `incident_logs`?; mark 24 old rows as legacy |

### 4.3 Proposed, not in the register (Q-X1)
| # | Topic | Status |
|---|---|---|
| A8 | Existing database reconciliation (baseline, additive changes, preservation) | Proposed; A8-Q1…Q5 |
| A9 | Actor model (user/operator/admin/automation/system/ai) | Proposed; A9-Q1…Q3 |
| A10 | Migration and deployment (environments, tooling, rollback, sign-off) | Proposed; A10-Q1…Q5, U13 |

### 4.4 New questions raised by this audit [DEC]

| # | Question | Why it matters |
|---|---|---|
| R1 | **DECIDED (D-003):** bring the Phase 19 documentation onto this branch, unchanged. Copy not yet performed. `schema.sql`/`001` are not included (open item B1-3 in the register). | C12. |
| R2 | **DECIDED (D-004):** Supabase CLI, migrations in `supabase/migrations/`. Historical SQL is preserved and not used as a baseline without verification. U13's execution identity is still open. | Determines every future file name. |
| R3 | Are the mobile screens with no backing table (s09 logs, s10 metrics, s13 repositories, s15 pipeline job, s23 assistant, s24 PR summary, s27 preferences) in database scope, served from external APIs through the backend, or out of scope? | Prevents inventing tables. |
| R4 | Notification channels: align the database to the UI (add slack/discord?), align the UI to the database, or both? Is a `notification_preferences` table wanted? | C9. |
| R5 | Mobile data path: backend API only, or also direct read-only Supabase queries/Realtime under RLS? (A2-Q2) | C16; drives grants for read tables. |
| R6 | Is the force-update of `feature/notifications` intentional? Where will the notifications code live (separate service or folded into the backend, A6-Q1)? | C10. |
| R7 | **DECIDED (D-002):** the ported middleware uses the user JWT and the per-request client; never service_role. | C1. |
| R8 | A4 protection style: allow-list (protected by default) or block-list? Which of restart/rollback/scale/circuit_breaker may ever run without approval? | C4, C18. |
| R9 | Database test tool: pgTAP through `supabase test db`, or plain SQL assertion scripts run on the rehearsal database? | Phase 13 test format. |
| R10 | Keep `incidents.service_name` alongside a new `service_id`, or migrate to `service_id` only (U6)? | C7. |
| R11 | Severity alignment (`info`) and where AI `root_cause` comes from. | C17. |
| R12 | **DECIDED (D-005):** a separate staging Supabase project; never production. Availability, plan and cost still unknown (register §4). | Phases 4–14 cannot run without it. |

Earlier open items still relevant: U1–U13 (`MIGRATION_EXECUTION_PLAN.md`); human decisions on existing data:
- approval `fdea11c4…` stays pending;
- run `e48ca6e7…` stays unchanged;
- "Test Restart Playbook" is not changed;
- no role is changed by migration.

---

## 5. Complete database work inventory

Every item below is **[Rec] pending the decision named in brackets**. Nothing here is approved.

### 5.1 Schema and relationships (A8, A3, A7)
- **Baseline:** `000_baseline` captured from the live schema **including grants and policies** (the current export has no grants). Mark `schema.sql` and `001` as historical (A8-Q4).
- **New tables** (columns per `MIGRATION_MAPPING.md` §2.5, §2.13, §2.18):
  - `incident_events` (timeline; FK incident → RESTRICT);
  - `notification_deliveries`;
  - `automation_runs` (`n8n_execution_id` UNIQUE).
- **New link columns (all nullable):**
  - `approvals.playbook_run_id` (U2);
  - `playbook_runs.automation_run_id`, `legacy_source` and `legacy_source_id`, plus an idempotency key column;
  - `recovery_checks.playbook_run_id`;
  - `ai_analyses.investigation_id`;
  - `incidents.archived_at` (soft delete, A8-Q5).
- **New approval columns:** `decision_reason`, `expires_at`.
- **Actor columns:** `actor_type` on audit and timeline (A9).
- **New status values:** approval `cancelled` and `expired` (A3).
- **Role value:** `profiles.role` gains `automation` (A5-Q1).
- **FK changes:**
  - incident children: CASCADE → RESTRICT, combined with soft delete (A8-Q5);
  - audit actor: RESTRICT or no FK (U8 / A7-Q3).
- **Legacy tables** (`incident_logs`, `audit_log`, `remediation_executions`): made read-only. Dropping them is a separate approval.

### 5.2 Constraints and indexes
- **CHECK constraints:** `approver_id <> requested_by`; a `system` actor may have a NULL `actor_id` only when `actor_type = 'system'`; a confidence range on new tables.
- **Partial UNIQUE indexes:**
  - one active run per (incident, playbook);
  - one pending approval per run;
  - one `n8n_execution_id`.
- **Adding constraints safely:** each one is added `NOT VALID`, then `VALIDATE`d after existing data has been checked (stage 5). Historical rows that break a new rule are documented, not rewritten.
- **Indexes:** the missing ones in §2.1, plus every new link column.

### 5.3 RLS policies and grants (A2, A3, A5, A6, R5)
- **Grants per table:** explicit grants, with no reliance on defaults. Revoke the inherited `Dxtm` on every new table.
- **Revoke direct client writes** on `approvals`, `playbook_runs`, `remediation_executions` and `audit_logs` (A2-Q3), in the **same release** as the backend switch to functions (C15).
- **Read access** for tables the mobile app and backend need (`services`, `deployments`, `ai_analyses`, `recovery_checks`, `notifications`, `incident_events`), scoped by role and incident ownership (R5).
- **Approver visibility:** `approvals` SELECT and UPDATE policies follow the A3-Q1 approver roles.
- **`device_tokens`:** a grant matching the existing own-row policies, or registration through a function (A6).
- **`profiles`:** never a table-wide UPDATE grant. A column grant (e.g. `full_name`) only, if needed (C6).
- **EXECUTE review:** remove client EXECUTE on trigger-only functions (`handle_new_user`, `rls_auto_enable`, `set_updated_at`) after rehearsal testing (P3c).
- **Automation role:** EXECUTE on machine functions only. It may never decide approvals or read audit.

### 5.4 Functions and triggers (A2, A3, A4, A5, A7, A9)

Proposed functions. All are SECURITY DEFINER with `SET search_path = ''`, check `auth.uid()` and the caller's role internally, write the audit entry in the same transaction, and are granted to named roles only.

| Function | Caller | Decision |
|---|---|---|
| `request_playbook_run(incident, playbook, idempotency_key, payload)`: checks enabled/protected, copies `approval_required`, creates the pending approval if protected | user/operator/admin | A3, A4 |
| `decide_approval(approval, decision, reason)`: sets `approver_id = auth.uid()`, compare-and-set on `pending` | approver roles (A3-Q1) | A3 |
| `cancel_approval` / `cancel_playbook_run` | requester / managers | A3 |
| `start_playbook_run(run)`: requires `approved`; protected ⇒ approval `approved` | automation (or manager) | A3, A5 |
| `complete_playbook_run(run, status, result, n8n_execution_id)` | automation (manual override per A3-Q3) | A3, A5 |
| `record_ai_analysis(...)` | automation | A5, A9-Q2 |
| `record_recovery_check(...)` | automation | A3 (U11) |
| `update_incident_status(incident, status)`: transition rules, recovery-check rule before `resolved` | managers | A3 (U11) |
| `log_audit_event(...)`: internal, **no client EXECUTE** | functions only | A7 |
| `add_incident_event(...)` | functions, automation | A7 |
| `register_device_token(...)` / `create_notification(...)` | user / automation | A6 |
| `expire_stale_approvals()` / `timeout_runs()` | `system` scheduler | A9-Q1 |
| `admin_update_user_role` (existing): keep human roles only | admin | A5-Q2 |

Proposed triggers:
- approvals: decided rows immutable;
- `audit_logs` and `incident_events`: append-only, plus a `BEFORE TRUNCATE` guard;
- optional enforcement triggers on direct writes (A2-Q5);
- optional audit triggers on direct-write tables such as incidents, playbooks and integrations (A7-Q7).

### 5.5 Approval and remediation workflow (A3, A4)

**Run states:**
- `pending_approval` → approved | rejected | cancelled
- `approved` → running | cancelled
- `running` → success | failed | cancelled
- A timeout ends a run in `failed`, with a reason.

**Approval states:** `pending` → approved | rejected | cancelled | expired.

**Rules:**
- Separation of duties, idempotency and compare-and-set, as in §5.2 and §5.4.
- Remediation writes move to `playbook_runs`.
- The legacy row `108d5a0d…` is copied with the same UUID and `legacy_source` (U1); status `succeeded` maps to `success`.
- Durations are open: A3-Q4.

### 5.6 Audit logging and incident history (A7)
- **`audit_logs` is trusted, append-only and admin-read.** It is written inside functions, and the action fails if the audit write fails (A7-Q1).
- **`incident_events` is the user-visible timeline.**
- **The 24 existing audit rows** are kept unchanged and marked legacy/untrusted (review proposal; A7-Q9). There is no back-fill of invented entries (U12).
- **Redaction:** no secrets, tokens, passwords or full email addresses in `details` or payloads.
- **Retention:** A7-Q2.

### 5.7 Existing data migration and preservation (A8)
- **All 46 records keep their UUIDs.** No deletes, overwrites or silent skips.
- **Unchanged rows:** pending approval `fdea11c4…` and pending run `e48ca6e7…` stay unchanged. They are on different incidents and are not linked [R].
- **Before and after every production stage:** per-table counts and checksums (checklist P1/P2, §D).
- **Test-data policy:** A8-Q1. Service records for the free-text names: U6 / R10.

### 5.8 Integration work
- **Backend (A1, A2):**
  - port the middleware, using the user JWT (R7), plus zod, helmet, Vitest/Supertest and the password reset;
  - call functions through `rpc(...)`;
  - route the execute step;
  - add machine endpoints for n8n (A5);
  - restrict CORS and add rate limiting;
  - return 403/409 instead of 500 on policy conflicts;
  - fix the `package.json` module type and add a test script.
- **n8n (A5):**
  - automation identity; no service_role or DB URL in its environment;
  - HTTPS, `N8N_BLOCK_ENV_ACCESS_IN_NODE=true`, a pinned image;
  - signed requests in both directions;
  - workflows for investigation, execution and recovery checks;
  - writes to `automation_runs`, `ai_analyses` and `recovery_checks` through endpoints.
- **Notifications (A6, R6):**
  - every route authenticated, user ID from the JWT, no service_role;
  - `device_tokens` / `notifications` / `notification_deliveries` names;
  - FCM credentials in a secret store.
- **Mobile (A1, R5):**
  - add a Supabase Auth client (to obtain the JWT) and a backend API client;
  - models for incidents, approvals, runs and timeline;
  - no privileged keys;
  - Realtime only if R5 allows it.

### 5.9 Tests (Phase 13)
- **Authorization matrix:** each role (anon, user, operator, admin, automation) × each table × each operation, through the **direct Supabase API** as well as the backend. Bypass attempts I1–I4 must fail.
- **Workflow scenarios:**
  - Each of these must be rejected: self-approval, a second decision, a protected run without approval, a disabled playbook, a duplicate active run, and an automation identity deciding an approval.
  - An idempotent replay must return the same run.
  - Expiry and timeout must work.
- **Audit:** one audit row per transition. UPDATE, DELETE and TRUNCATE are rejected. A failed audit write rolls back the action.
- **Data:** 46 records preserved by ID, counts and checksums. The legacy copy is verified.
- **Integration:**
  - backend Vitest/Supertest;
  - n8n end-to-end on rehearsal (signature, replay rejection, execution ID uniqueness);
  - notifications authentication;
  - mobile against the rehearsal backend.
- **Rollback:** timed rehearsal of levels 1–3.

### 5.10 Documentation
- Decision records for A2–A7 (and A8–A10 if accepted).
- Updated mapping and plan.
- Migration log: who, when, which identity, hash.
- RLS and grant matrix.
- Function reference.
- Runbook for rollback.
- Handover notes for backend, n8n and mobile.

---

## 6. Phased implementation roadmap

Mapping to the existing plan (`MIGRATION_EXECUTION_PLAN.md` stages 0–13) is shown per phase. **Phases 4–15 must not start until their listed decisions are approved.** No phase touches production before Phase 15.

### Phase 1 – Audit and roadmap ✅ (this document)
- **Tasks:** inspect the repository, branches, documents, schema export and integrations; list conflicts and decisions.
- **Files:** `database/COMPLETE_DATABASE_IMPLEMENTATION_ROADMAP.md` (new).
- **Completion criteria:** roadmap reviewed by the team.

### Phase 2 – Decision approval (plan stage 0 + stage 1 decisions)
- **Tasks:**
  1. Decide Q-X1 (is A8–A10 in scope?).
  2. Approve A2–A7 in order: A2 → A5 → A3 → A4 → A7 → A6. A6 goes last because of R6.
  3. Answer U1–U13 and R1–R12.
  4. Record each decision with date and approver.
- **Dependencies:** none.
- **Files:** a decision record, e.g. `database/ARCHITECTURE_DECISIONS.md` (new), or updates to the register in `MIGRATION_EXECUTION_PLAN.md` once R1 brings it onto this branch.
- **Risks and precautions:** don't treat report recommendations as approved; record exact wording.
- **Tests:** none.
- **Completion criteria:** every A2–A7 entry is APPROVED or explicitly deferred with a reason; every [DEC] item in §4 has an answer; the blocker is lifted in writing.

### Phase 3 – Repository consolidation (no database change)
- **Tasks:**
  1. ✅ **Done 2026-11-07:** cherry-picked `fff81bf`, `56c6b82` and `030df62` as `41b6772`, `bb11fdb` and `55c9a1b`, unchanged (D-003, D-006). The wording context is in `database/HISTORICAL_CONTEXT_NOTE.md`.
  2. Install and pin the Supabase CLI, then run `supabase init` to create `supabase/config.toml` and `supabase/migrations/` (D-004). Don't link to any project until the D-009 ownership and credential confirmation is recorded.
  3. Add the agreed test folder (R9).
  4. Add a `database/README.md` note on conventions and on the "current branch" wording in the copied documents (register §5.3).
- **Dependencies:** D-003, D-004 (decided); B1-1, R9 (open).
- **Files:**
  - the five `database/*.md` documents (copied unchanged);
  - `supabase/config.toml`, `supabase/migrations/` (new);
  - a test folder (per R9);
  - `database/README.md`.
- **Risks and precautions:**
  - Don't edit the copied documents.
  - Historical SQL (`schema.sql`, `001`) stays on `feature/database`; it isn't copied into `supabase/migrations/` (register §6; B1-3).
  - No `supabase link` and no secrets in `config.toml`.
- **Tests:** none.
- **Completion criteria:** one branch holds the plan, history and folders; reviewed by pull request.

### Phase 4 – Environments, backup and restore (plan stage 2; A10)
- **Tasks:**
  1. Provision the **separate staging Supabase project** (D-005), matching PostgreSQL 17 and the production Auth settings. Requirements are in register §4. Link the CLI to **staging only**.
  2. Take a fresh custom-format dump **plus a roles/grants dump**, and record their hashes.
  3. Test-restore into rehearsal.
  4. Compare counts and checksums with the P1/P2 baselines.
  5. Verify the Supabase CLI execution identity, read-only, on staging (U13 identity part; the method is decided by D-004).
- **Dependencies:** Phase 2:
  - D-005 decided; D-007 synthetic data decided.
  - D-009 owner decided: the team leader, organization `AI-DevOps-CommandCenter`, proposed `devops-command-center-staging` in `ap-southeast-1`.
  - Still pending: D-009 credential storage and access assignments, and staging availability and cost.
- **Files:** `database/MIGRATION_LOG.md` (new); a restore-verification record.
- **Risks and precautions:**
  - Backups contain personal data: store them outside git and never print them.
  - Never rehearse on production.
- **Tests:** restore verification, 46 records.
- **Completion criteria:** the restore is proven and timed, and the identity is verified.

### Phase 5 – Baseline migration (A8)
- **Tasks:**
  1. Generate the baseline from the live schema, including grants, policies and the database-level objects missing from the `public` export: the `ensure_rls` event trigger and the `on_auth_user_created` trigger (register §4.3).
  2. Verify on staging that it reproduces the live structure. Don't treat it, or `001`, as production-ready without that verification (D-004).
  3. Marking the baseline as applied on production is a separate approval at Phase 15.
- **Dependencies:** Phase 4, A8-Q4.
- **Files:** `supabase/migrations/<timestamp>_baseline.sql`. Later migration names in this roadmap (`002_…` to `009_…`) take the same `<timestamp>_<name>.sql` form.
- **Risks and precautions:** the baseline must not contain data or secrets.
- **Tests:** schema diff live vs rebuilt = empty.
- **Completion criteria:** the baseline is reviewed and becomes the source of truth.

### Phase 6 – Backend groundwork (no database change; A1, A2)
- **Tasks:**
  1. Port the middleware **using the user-JWT client** (R7).
  2. Add zod validation, helmet, CORS restriction and rate limiting.
  3. Add Vitest/Supertest and a test script.
  4. Fix the `package.json` module type.
  5. Add the password reset (public client).
  6. Add a machine-endpoint skeleton (A5), disabled until Phase 11.
- **Dependencies:** D-001 and D-002 (decided). The rest of A2 for the machine endpoints. This is application work, so it needs its own review.
- **Files:**
  - `backend/src/middleware/auth.ts`;
  - new `backend/src/middleware/role.ts`, `backend/src/middleware/machine-auth.ts`, `backend/src/validation/*`, `backend/src/routes/auth.routes.ts`;
  - `backend/src/server.ts`, `backend/package.json`;
  - `backend/tests/*`.
- **Risks and precautions:** no service_role import; keep the behaviour of existing endpoints.
- **Tests:** unit and route tests, and a grep showing no `SERVICE_ROLE` in `backend/src`.
- **Completion criteria:** tests pass; the code is reviewed and merged on its own.

### Phase 7 – Additive schema (plan stage 3; A3, A5, A7, A8, A9)
- **Tasks:**
  1. Create the 3 new tables.
  2. Add nullable link, actor and idempotency columns.
  3. Add new status values and the `automation` role value.
  4. Add indexes.
  5. **Revoke `Dxtm` on every new table** in the same migration.
- **Dependencies:** Phases 4–5; A3, A5, A7 approved.
- **Files:** `<migrations>/002_additive_tables_and_columns.sql`, `003_indexes.sql` (names follow R2).
- **Risks and precautions:**
  - Additive only: no renames, drops or NOT NULL on existing columns.
  - Run on rehearsal first.
- **Tests:** the migration applies cleanly; the 46 records are unchanged; new tables are inaccessible to clients until Phase 11.
- **Completion criteria:** the stage 3 gate is passed and recorded.

### Phase 8 – Backfill and mapping (plan stage 4; A8, U1)
- **Tasks:**
  1. Copy remediation `108d5a0d…` into `playbook_runs` with the same UUID and `legacy_source` (if U1 = `playbook_runs`).
  2. Set `approval_required` on existing runs from their playbook.
  3. Mark the 24 audit rows legacy (if A7-Q9).
  4. Optionally link incidents to services (U6/R10).
- **Dependencies:** Phase 7. Must run **before** Phase 10's triggers (C14).
- **Files:** `<migrations>/004_backfill_legacy.sql`.
- **Risks and precautions:**
  - No invented approvals, timestamps or services.
  - The existing pending rows stay unchanged.
- **Tests:** per-record checks from checklist §D; source rows still present.
- **Completion criteria:** every record is mapped or flagged for manual review.

### Phase 9 – Constraints and foreign keys (plan stage 5)
- **Tasks:**
  1. Add the CHECKs and partial UNIQUE indexes as `NOT VALID`, then `VALIDATE`.
  2. Change the FK delete behaviour (RESTRICT plus soft delete; audit actor per U8).
- **Dependencies:** Phase 8; A8-Q5, U8.
- **Files:** `<migrations>/005_constraints_and_fks.sql`.
- **Risks and precautions:**
  - Validate on rehearsal first. Historical violations are documented, not rewritten.
  - Check the effect on Supabase Auth user deletion (C13).
- **Tests:** constraint violation tests; existing data validates.
- **Completion criteria:** all constraints are valid.

### Phase 10 – Functions and triggers (plan stage 6; A2, A3, A4, A7, A9)
- **Tasks:**
  1. Create the workflow functions in §5.4, with `REVOKE ALL ... FROM PUBLIC, anon` followed by explicit grants.
  2. Add the immutability, append-only and TRUNCATE guards.
  3. Add the protected-playbook rule (R8).
  4. Add the scheduler jobs, if A9-Q1 allows them.
- **Dependencies:** Phases 8–9.
- **Files:** `<migrations>/006_workflow_functions.sql`, `007_audit_and_guards.sql`, `008_scheduled_jobs.sql` (if approved).
- **Risks and precautions:**
  - A careless SECURITY DEFINER function can escalate privileges. Use `search_path = ''`, qualify every object name, check the role inside each function, and peer-review all of them.
- **Tests:** the workflow scenarios in §5.9 at SQL level.
- **Completion criteria:** all scenario tests pass on rehearsal.

### Phase 11 – RLS, grants and the backend switch (plan stage 7; A2, A5, A6, R5)
- **Tasks:**
  1. Apply the new grant and policy matrix.
  2. Revoke direct client workflow and audit writes.
  3. Review client EXECUTE on trigger functions.
  4. Provision the automation identity.
  5. In the **same release**, switch the backend to `rpc(...)`, route the execute step and enable the machine endpoints.
- **Dependencies:** Phases 6 and 10.
- **Files:**
  - `<migrations>/009_rls_and_grants.sql`;
  - backend `services/approval.service.ts`, `services/playbook-run.service.ts`, `services/remediation-execution.service.ts`, `services/audit.service.ts`, `services/incident.service.ts`, `services/investigation.service.ts`, their controllers and routes, plus new `backend/src/routes/machine.routes.ts`.
- **Risks and precautions:**
  - Lock-out: test every role before release.
  - Never grant table-wide UPDATE on `profiles` (C6).
- **Tests:** the authorization matrix (§5.9), including direct-API bypass attempts.
- **Completion criteria:** the matrix passes and the backend tests pass.

### Phase 12 – Integrations: n8n, notifications, mobile (A5, A6, R3–R6)
- **Tasks:**
  - **n8n:**
    1. Harden the compose file (HTTPS, env-access block, pinned image).
    2. Remove service_role and the DB URL from its environment template.
    3. Build workflows that call the machine endpoints with signed requests.
    4. Verify the backend → n8n webhook signature.
  - **Notifications:** rebuild or restore according to R6/A6-Q1, with authentication, JWT user ID and schema-aligned names.
  - **Mobile:** add the auth and API client and data models; wire the screens that have backing data (R3).
- **Dependencies:** Phase 11.
- **Files:**
  - `automation/docker-compose.yml`, `automation/workflows/*.json`, `.env.example` (names only, on the n8n branch);
  - `notifications/src/*` or a backend notifications module;
  - `mobile/pubspec.yaml`, new `mobile/lib/services/*`, `mobile/lib/models/*`, the affected screens.
- **Risks and precautions:**
  - No secrets in workflow exports.
  - FCM credentials go in a secret store.
  - The mobile app holds no privileged keys.
- **Tests:** n8n end-to-end on rehearsal; notification authentication tests; mobile integration tests.
- **Completion criteria:** end-to-end incident → investigation → approval → execution → recovery → postmortem works on rehearsal.

### Phase 13 – Full validation (plan stages 8–11)
- **Tasks:** run the complete §5.9 suite and record the results.
- **Dependencies:** Phases 7–12.
- **Files:** `database/tests/*`; `database/TEST_RESULTS.md` (new).
- **Risks and precautions:** test on rehearsal only.
- **Completion criteria:**
  - all tests pass;
  - 46 records preserved (IDs, counts, checksums);
  - the security checklist §V is signed.

### Phase 14 – Rollback rehearsal (plan stage 12)
- **Tasks:** rehearse and time level 1 (app revert), level 2 (policy/grant restore) and level 3 (data restore). Define the rollback triggers in advance.
- **Dependencies:** Phase 13.
- **Files:** `database/ROLLBACK_RUNBOOK.md` (new).
- **Completion criteria:** each level is restored successfully within the agreed time.

### Phase 15 – Production migration (plan stage 13)
- **Tasks:**
  1. Owner sign-off per stage.
  2. A maintenance window with n8n paused.
  3. A fresh backup plus a grants dump.
  4. Apply the migrations in order with the verified identity.
  5. Run the post-migration validation.
  6. Record everything in the migration log.
- **Dependencies:** Phases 4, 13 and 14; written owner approval.
- **Files:** `database/MIGRATION_LOG.md`.
- **Risks and precautions:** stop and roll back on any failed gate.
- **Completion criteria:** production validated, with 46 records preserved.

### Phase 16 – Post-migration and legacy retirement (separate approval)
- **Tasks:**
  1. Soak period and monitoring.
  2. Retire the legacy tables: first revoke writes, then rename as deprecated, and drop only after a fresh backup and a new approval.
  3. Final documentation and handover.
- **Files:** `<migrations>/0xx_retire_legacy_*.sql` (later); updated documents.
- **Completion criteria:** legacy retired with sign-off; documentation complete.

---

## 7. Files expected to change in future phases

| Area | Files | Phase |
|---|---|---|
| Decisions and docs | `database/ARCHITECTURE_DECISIONS.md` (new) or the register in `MIGRATION_EXECUTION_PLAN.md`; Phase 19 documents brought onto this branch (R1); `database/README.md`; `database/MIGRATION_LOG.md`, `database/TEST_RESULTS.md`, `database/ROLLBACK_RUNBOOK.md` (new) | 2–3, 13–16 |
| Migrations (`supabase/migrations/<timestamp>_<name>.sql`, D-004; plus `supabase/config.toml`) | `baseline`; `001_align_with_proposal.sql` stays historical on `feature/database` and is not copied (register §6); `002_additive_tables_and_columns.sql`; `003_indexes.sql`; `004_backfill_legacy.sql`; `005_constraints_and_fks.sql`; `006_workflow_functions.sql`; `007_audit_and_guards.sql`; `008_scheduled_jobs.sql` (if approved); `009_rls_and_grants.sql`; later `0xx_retire_legacy_*.sql` | 5–11, 16 |
| Database tests (format per R9) | `database/tests/auth_matrix.*`, `workflow_scenarios.*`, `audit_guards.*`, `data_preservation.*` | 7–13 |
| Backend | `backend/package.json`; `backend/src/server.ts`; `backend/src/config/supabase.ts`; `backend/src/middleware/auth.ts` (+ new `role.ts`, `machine-auth.ts`); `backend/src/validation/*` (new); `backend/src/routes/auth.routes.ts`, `machine.routes.ts` (new), `playbook-run.routes.ts`, `remediation-execution.routes.ts`; services and controllers for approval, playbook-run, remediation-execution, audit, incident, investigation, admin-playbook; `backend/tests/*` (new) | 6, 11 |
| n8n | `automation/docker-compose.yml`; `automation/workflows/*.json` (new); `.env.example` (variable names only) | 12 |
| Notifications | `notifications/src/*` (per R6), or a new backend notifications module | 12 |
| Mobile | `mobile/pubspec.yaml`; `mobile/lib/services/*`, `mobile/lib/models/*` (new); data-backed screens (R3) | 12 |

---

## 8. Cross-cutting risks and precautions

| Risk | Precaution |
|---|---|
| Data loss | Additive first; same UUIDs; nothing dropped; per-table counts and checksums before and after; proven restore. |
| Privilege escalation via SECURITY DEFINER | `search_path = ''`, qualified names, role checks inside, `REVOKE ... FROM PUBLIC, anon`, peer review, tests. |
| Lock-out after revoking grants | Ship the backend switch in the same release; test the authorization matrix first. |
| Secrets exposure | Never print `.env` or backups; secret stores per environment; no keys in workflow exports or templates; integration secrets in Vault (A2-Q4). |
| Inherited TRUNCATE on new tables | Revoke `Dxtm` in the same migration that creates the table. |
| Self-role escalation | Never grant table-wide UPDATE on `profiles` (C6); roles only via `admin_update_user_role`. |
| Legacy copy rejected by new triggers | Phase 8 before Phase 10 (C14). |
| Audit rewritten by user deletion | Decide U8 before the append-only trigger (C13). |
| Production rehearsal | Never: all stages run on rehearsal first; only Phase 15 touches production. |
| Scope creep from the mobile UI | No table is created for a screen until R3 is answered. |

---

## 9. Exact next step

**Decision Batches 1 and 1b are recorded** (D-001 to D-009; `database/DATABASE_DECISION_REGISTER.md`). **Phase 3 step 1 is done** (commits `41b6772`, `bb11fdb`, `55c9a1b`).

Next:
1. **Phase 3, step 2:** install and pin the Supabase CLI and run `supabase init`, with no `supabase link` (D-004, D-009). Needs the team's go-ahead.
2. **Decision Batch 2:** Q-X1; the rest of D-009 (credential storage and individual access; the owner is already decided); B1b-1 (production backup restore test); staging availability and cost (A10-Q1); the remaining A2 sub-questions.

Phase 6 (backend middleware, D-002) may start after Phase 3. No SQL is written until all of A2–A7 are approved.

---

*Planning document only. A1 is APPROVED; A2–A7 are PENDING; A8–A10 are PROPOSED; R1–R12 are new open questions. Nothing described here has been implemented.*
