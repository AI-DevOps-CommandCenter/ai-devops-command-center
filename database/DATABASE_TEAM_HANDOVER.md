# Database Team Handover

**Project:** AI-Powered Mobile DevOps Command Center
**Date:** 2026-11-07
**Branch:** `feature/database-implementation` (local commits, not pushed)

> **Status in one line (updated 2026-11-07, Batch 2):**
> - **Done, tested locally:** the verified baseline, the additive structure, and the **A2–A7 security and workflow logic** (migrations 000400–000700; 12 suites, 304 assertions, 0 failures).
> - **Gate before any remote apply:** the backend must switch from direct table writes to the new functions **in the same release** (§1a). The current backend code breaks against 000500/000700.
> - **Not yet done:** staging rehearsal (D-009 credentials still open) and the production migration.
>
> **The database is complete locally for A2–A7. It is not applied anywhere remote.**

---

## 1. What you can start developing against NOW

| Team | Start now | Contract |
|---|---|---|
| **Mobile (Flutter)** | <ul><li>Sign in with Supabase Auth (email/password) to get the access token.</li><li>Call the backend with `Authorization: Bearer <token>`.</li><li>Direct Supabase **reads** of the user's own data are allowed under RLS (A2): incidents, approvals, playbook runs, timeline (`incident_events`), AI analyses, recovery checks, own notifications, own devices.</li><li>Every **write** goes through the backend. Use an idempotency key (8–200 chars) when requesting a run.</li><li>Show approve/reject only to admins and operators, never on their own requests.</li></ul> | Part A, and Part B.2 (implemented) |
| **Backend** | **Required before any remote apply (§1a):** switch to `rpc(...)` for every workflow write. Map the `DC4xx` error codes to HTTP (Part B.1). Mount the machine endpoints with `machineAuth()` (`backend/src/middleware/machine-auth.ts`, tested). | Part B (implemented) |
| **n8n** | <ul><li>Build workflows against the machine endpoints (Part B.3).</li><li>Sign every request (HMAC, nonce, timestamp). The signing helpers are in `machine-auth.ts`.</li><li>Report results with the **same** `n8n_execution_id` that started the run.</li><li>No service_role, no database URL, no Supabase key in n8n.</li></ul> | Part B.3 (implemented on the database/backend side) |
| **Notifications** | Backend notification module (A6): claim pending deliveries with `claim_notification_deliveries()`, send them with provider credentials kept on the backend, then record each result with `record_notification_delivery()`. | Part B.4 (implemented) |

### 1a. Release gate: backend switch (owner: backend team)
> **Status (2026-11-08):** implemented on branch `feature/backend-rpc-integration` (not merged yet). All rows below are done. Approvals and playbook runs use the database functions, remediation writes return 410, and the backend no longer writes `audit_logs`. Machine endpoints for n8n are mounted but disabled until the automation user exists (A5-Q2). Tests: backend 121, database suite 14 (exactly one audit entry per action).

Migrations 000500 and 000700 revoke the direct client writes the current controllers use. These calls must change in the **same release** as the migrations:

| Current code (`backend/src/services/…`) | Replace with |
|---|---|
| `approval.service.ts` insert/update `approvals` | `request_playbook_run` (creates the approval), `decide_approval`, `cancel_approval` |
| `playbook-run.service.ts` insert/update `playbook_runs` | `request_playbook_run`, `decide_approval`, `cancel_playbook_run`; n8n: `start_playbook_run` / `complete_playbook_run` |
| `remediation-execution.service.ts` insert/update | Retired (read-only legacy). Use playbook runs. |
| `audit.service.ts` insert into `audit_logs` | Remove all 16 calls. The functions (workflow) and the triggers of 000800 (incidents, postmortems, playbooks, integrations, role changes) write the audit entry themselves, atomically. |

Reads keep working unchanged. The current code catches audit failures, so those calls fail silently; the approval, run and remediation writes return 500 until they are switched.

---

## 2. Schema overview

22 `public` tables: 18 live, verified, plus 3 new target tables, plus `automation_request_nonces` (A5, function-only).

> The diagram and the "Client access today" column below describe the **baseline** (before A2–A7). For access after migrations 000400–000700, use the role matrix further down. After A7-Q3, `audit_logs.actor_id` and `incident_events.actor_id` are plain IDs with **no FK** to profiles.

```mermaid
erDiagram
    auth_users ||--|| profiles : "on_auth_user_created"
    profiles ||--o{ incidents : created_by
    services ||--o{ incidents : service_id
    services ||--o{ deployments : service_id
    deployments ||--o{ incidents : deployment_id
    incidents ||--o{ investigations : ""
    incidents ||--o{ ai_analyses : ""
    investigations ||--o{ ai_analyses : "investigation_id (new)"
    incidents ||--o{ approvals : ""
    incidents ||--o{ playbook_runs : ""
    playbooks ||--o{ playbook_runs : "RESTRICT"
    incidents ||--o{ remediation_executions : "legacy"
    incidents ||--o{ recovery_checks : ""
    playbook_runs ||--o{ recovery_checks : "playbook_run_id (new)"
    incidents ||--|| postmortems : "one per incident"
    incidents ||--o{ incident_events : "new, RESTRICT"
    incidents ||--o{ automation_runs : "new, RESTRICT"
    playbook_runs ||--o{ automation_runs : "new, RESTRICT"
    automation_runs ||--o{ recovery_checks : "automation_run_id (new)"
    profiles ||--o{ notifications : user_id
    notifications ||--o{ notification_deliveries : "new, CASCADE"
    profiles ||--o{ device_tokens : user_id
    device_tokens ||--o{ notification_deliveries : "new, SET NULL"
    profiles ||--o{ audit_logs : actor_id
```

| Table | Purpose | Rows in production [R] | Client access today |
|---|---|---|---|
| profiles | One per auth user; `role` = user/admin/operator | 2 | read own (admin: all) |
| services | Monitored services | 2 | none |
| deployments | Deployments per service | 0 | none |
| incidents | Incidents (free-text `service_name`; `service_id` unused) | 3 | own (managers: all); create own; managers update |
| investigations | Investigation records per incident | 4 | as incident; managers update |
| ai_analyses | AI results per incident (+ `investigation_id`, new) | 0 | none |
| playbooks | Remediation playbooks (`action_type` restart/rollback/scale/circuit_breaker) | 5 | enabled only (admin: all, manage) |
| playbook_runs | Run requests and their lifecycle (+ `automation_run_id`, new) | 1 | own (managers: all); managers decide |
| approvals | Incident-level approval requests | 1 | own (admin: all); admin decides |
| remediation_executions | **Legacy** execution records | 1 | managers |
| recovery_checks | Post-remediation health checks (+ run/automation/checked_by links, new) | 0 | none |
| postmortems | One per incident | 3 | as incident; managers write |
| notifications | Inbox per user | 0 | none |
| device_tokens | Push tokens | 0 | none (policies exist, no grant) |
| integrations | Integration settings | 0 | admin |
| audit_logs | Audit trail | 24 | insert own; admin read |
| audit_log, incident_logs | **Legacy**, unused | 0 | insert/read via policies (incident_logs) |
| **automation_runs** (new) | n8n executions; unique `n8n_execution_id` | – | **none** (pending A5) |
| **incident_events** (new) | Incident timeline | – | **none** (pending A7) |
| **notification_deliveries** (new) | Delivery attempts per channel/device | – | **none** (pending A6) |

**Functions (verified, unchanged):**
- `admin_update_user_role(uuid, text)`: admin only, not self, human roles only.
- `is_admin()`, `is_incident_manager()`: used by the policies.
- `handle_new_user()`: sign-up trigger.
- `rls_auto_enable()`: event trigger.
- `set_updated_at()`.

**Triggers:**
- `updated_at` on 6 tables;
- `on_auth_user_created` on `auth.users`;
- event trigger `ensure_rls`, which enables RLS on every new public table.

**Functions added by A2–A7 (migrations 000400–000700):** see `API_AND_INTEGRATION_CONTRACTS.md` Part B.2. All of them are `SECURITY DEFINER`, use `search_path = ''`, check the caller's role themselves, and take the actor from the JWT. Internal helpers (`require_app_role`, `log_audit_event`, `write_incident_event`, `write_notification`, `notify_approvers`, `redact_sensitive`) cannot be called by clients.

**Triggers added:** `guard_automation_role` (profiles), append-only and no-truncate guards on `audit_logs` and `incident_events`, and `approvals_immutable_decision` / `approvals_no_truncate`.

### Role and permission matrix (after A2–A7; verified by tests 02, 05, 06, 09–12)

| Action | anon | user | operator | admin | automation (backend for n8n) |
|---|---|---|---|---|---|
| Read own profile / all profiles | – | own | own | all | own |
| Change roles | – | – | – | others only; never to or from `automation` | – |
| Create incident | – | own | own | own | own |
| Read incidents, timeline, AI analyses, recovery checks | – | own incidents | all | all | – |
| Update incidents | – | – | ✓ | ✓ | – |
| Request a playbook run (creates its approval) | – | own incident | ✓ | ✓ | – |
| Decide an approval | – | – | ✓ (never own) | ✓ (never own) | – |
| Cancel a pending request | – | own | own / any | own / any | – |
| Cancel an approved or running run | – | – | ✓ (reason) | ✓ (reason) | – |
| Start a run | – | – | – | – | ✓ (approved runs only) |
| Complete a run | – | – | ✓ manual, reason | ✓ manual, reason | ✓ (matching execution id) |
| Record AI analysis | – | – | – | – | ✓ |
| Record recovery check | – | – | ✓ | ✓ | ✓ |
| Timeline: add comment / operational event | – | – | comment | comment | log, investigation, remediation, recovery, notification |
| Read audit logs | – | – | – | ✓ | – |
| Write audit logs | nobody directly: only inside the functions, atomically | | | | |
| Change or delete audit/timeline/decided approvals | nobody (owner included) | | | | |
| Notifications | – | read own, mark read, register own device | same | same | create, claim and record deliveries |
| Manage playbooks / integrations | – | – | – | ✓ | – |
| Delete incidents | – | – | – | – (no grant) | – |

---

## 3. Migrations (in order)

| # | File | Kind | Status |
|---|---|---|---|
| 1 | `supabase/migrations/20261107000000_baseline_live_public_schema.sql` | Baseline of the verified live schema, with grants and the two database-level triggers | Tested locally. **Not to be executed on production**: there it is only *marked* as applied, in a separately approved step. |
| 2 | `20261107000100_add_missing_fk_indexes.sql` | 10 indexes | Tested locally |
| 3 | `20261107000200_create_target_tables.sql` | 3 new tables, no client access | Tested locally |
| 4 | `20261107000300_add_target_link_columns.sql` | 5 nullable link columns | Tested locally |
| 5 | `20261107000400_automation_identity.sql` | **A5:** `automation` role (owner-only), role helpers, replay-protection nonce store | Tested locally |
| 6 | `20261107000500_trusted_audit_and_timeline.sql` | **A7:** append-only audit and timeline (all roles), actor FK removed (A7-Q3), internal audit writer, no client audit INSERT, timeline read policy | Tested locally |
| 7 | `20261107000600_notifications.sql` | **A6:** channels in_app/push/email/slack/discord, own-inbox reads, device-token and delivery functions | Tested locally |
| 8 | `20261107000700_approval_workflow.sql` | **A2/A3/A4:** approvals linked 1:1 to runs, `cancelled` status, separation CHECKs, idempotency, one active run per incident+playbook, immutable decisions, workflow functions, direct client writes revoked | Tested locally. **Release gate §1a.** |
| 9 | `20261107000800_audit_coverage_and_redaction.sql` | **A7 review fixes:** audit triggers on incidents, postmortems, playbooks, integrations and role changes (API actions, fail closed); incident status changes on the timeline; recursive redaction of run and automation payloads | Tested locally |

- **Rollback:** `database/rollback/<migration>.down.sql`. Apply in reverse order. Each script refuses to run if it would destroy data. Guards for 000200, 000400 and 000700 are exercised by the test runner.
- **Historical SQL** (`origin/feature/database:database/schema.sql`, `001_align_with_proposal.sql`) is unchanged and is **not** a baseline (D-008).
- **Existing rows are never modified** by 000400–000700 (verified by the data-preservation checksums).

**Not implemented (still open):** incident status transitions and the recovery rule (U11; GAP-07/08 remain open), approval expiry and run timeouts (A3-Q4: not now), actor-type columns (A9), soft delete (A8-Q5), legacy row copy (U1). See §7.

---

## 4. Local setup and tests

### Option 1: throwaway PostgreSQL cluster (no Docker; used for the results above)
Needs PostgreSQL 17+ server binaries (installed here: 18.6 under `C:\Program Files\PostgreSQL\18`).
```bash
bash database/tests/run-local-db-tests.sh            # Git Bash, from the repository root
TEST_PG_PORT=55450 bash database/tests/run-local-db-tests.sh   # other port
KEEP_CLUSTER=1 bash database/tests/run-local-db-tests.sh       # keep it running to inspect
```

The script:
1. creates a temporary cluster on `127.0.0.1:55441`;
2. applies a small Supabase shim (`database/tests/harness/supabase_shim.sql`: roles, `auth.users`, `auth.uid()`);
3. applies the migrations and the synthetic seed;
4. checks data preservation, runs every `database/tests/sql/*.sql` suite, and does a full rollback round-trip;
5. deletes the cluster.

It never connects to a remote database.

### Option 2: local Supabase stack (needs Docker Desktop running; first start downloads several GB)
```bash
npx supabase start        # pinned CLI 2.122.0 (root package.json)
npx supabase db reset     # applies supabase/migrations + supabase/seed.sql to the LOCAL stack only
npx supabase status       # local URLs and local development keys
DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres bash database/tests/run-local-db-tests.sh
npx supabase stop
```
- **Never** run `supabase link` or `db push` until staging is approved (D-009).
- Option 2 hasn't been executed yet, because Docker Desktop isn't running.
- **Local sign-in users:** the seed users can't sign in. Create a user in local Studio (`http://127.0.0.1:54323`, Authentication → Add user), then set its role in the local SQL editor:

  ```sql
  update public.profiles set role = 'admin' where email = '<your local test email>';
  ```

### Synthetic data
`supabase/seed.sql` contains only invented values, in the same per-table shape as production (46 rows). D-007 applies: never copy production data.

### Current results (executed 2026-11-07, PostgreSQL 18.6 throwaway cluster)
- **Database: 13 test files, 325 assertions, 0 failures** (was 8 files / 179 before A2–A7).
- **Data preserved** across migrations, rollback, re-apply and the rollback-guard probes (46 synthetic rows, byte-identical checksums).
- **Rollback guards work** for 000200, 000400 and 000700.
- **Backend: 9 test files, 69 tests, 0 failures** (`npx vitest run`), including 15 for n8n request signing and replay protection (`tests/machine-auth.test.ts`). `tsc --noEmit` is clean.
- **Production is PostgreSQL 17.** Staging rehearsal (P7) must repeat the run on 17.

Suites 01–08 were updated in place where A2–A7 deliberately change behaviour. Each changed assertion names its decision.

| Suite | Covers |
|---|---|
| 01 | Baseline structure (+3 read policies, actor FK removed), ensure_rls, triggers |
| 02 | Client grants after all migrations (baseline values; changes marked per decision) |
| 03 | CHECK/UNIQUE/FK behaviour (automation role, cancelled status, A6 channels, actor id kept on user deletion) |
| 04 | Sign-up trigger, `updated_at`, role function |
| 05 | RLS per role, anon, own-inbox reads |
| 06 | Approval rules: 1:1 link, admin + operator decide, never own, immutable for every role, legacy deadlock |
| 07 | Known gaps: GAP-01…06, 09, 10 **closed**; GAP-07/08 **open** (U11) |
| 08 | New tables: function-only access, timeline read, duplicate n8n execution blocked, links, indexes |
| 09 | **A5:** automation role guard, replay protection, machine-only functions, automation never requests or decides |
| 10 | **A3/A4:** idempotency, duplicate execution, approval bypass attempts, manual override, cancellation, AI and recovery records |
| 11 | **A7:** actor from JWT, fail-closed atomic audit, redaction, append-only for the owner, timeline access |
| 12 | **A6:** device tokens, inbox RLS, approver notifications, Slack/Discord broadcast, delivery claim/record |
| 13 | **A7 review fixes:** audit of incident/postmortem/playbook/integration/role changes, fail closed, settings never audited, status timeline, recursive redaction for every writer |

---

## 5. Staging setup (when D-009 is complete)
1. **Team leader creates the project.** Name: `devops-command-center-staging`. Region: `ap-southeast-1` (proposed). Organization: `AI-DevOps-CommandCenter`. PostgreSQL 17.
2. **Record the remaining items in `DATABASE_DECISION_REGISTER.md` (D-009):** where the credentials are stored, and who gets which access.
3. **Explicit approval to connect**, then `npx supabase link --project-ref <staging ref>` and `npx supabase db push` (staging only).
4. **Seed synthetic data only.** Configure Auth: email provider, staging redirect URLs.
5. **Run the tests against staging, and verify the CLI identity (U13).**
6. **Rehearse the rollback.**

## 6. Production (not started; never automatic)
**Prerequisites:**
- staging rehearsal passed;
- point-in-time recovery confirmed (A10-Q3);
- fresh backup plus a separate roles/grants dump;
- read-only "before" counts and checksums (checklist P1/P2/§D);
- rollback rehearsed;
- migration log prepared;
- **explicit written approval**.

**Steps:**
1. Mark the baseline as applied. It is **not executed**; the objects already exist.
2. Apply migrations 2–8 **together with the switched backend** (§1a).
3. Provision the automation identity (owner, SQL Editor; procedure A5-Q2).
4. Verify the 46 production records.

---

## 7. Decisions

**A2–A7 were approved on 2026-11-07 (Decision Batch 2) and are implemented locally** in migrations 000400–000700. See `DATABASE_DECISION_REGISTER.md` §2c for the exact wording and the sub-answers (A3-Q1, A3-Q3, A3-Q4, A7-Q3).

### Still open (none blocks the work done; each blocks only what is listed)

| Item | Why it matters | Blocks |
|---|---|---|
| **Backend switch (§1a)** | Backend team, owner of the controllers | Any remote apply of 000500/000700 |
| **A5-Q2** automation identity: who provisions, rotates and revokes it; where the backend keeps its credentials (A2-Q4) | Only the database owner can assign the role | Staging and production use of the machine endpoints |
| **A3-Q2** the seeded/live deadlocked approval `fdea11c4…` (no run linked) | An operator can now decide it, or the admin can cancel it. Which one is a human decision. | Nothing technical |
| **A3-Q5 / U1** legacy rows: approval with no run, run with no approval, remediation execution `108d5a0d…` | They stay as they are. The run without an approval can never be started (A4). | Legacy copy |
| **A3-Q4** approval expiry and run timeouts | "Not now". Stale items are cancelled by people. | Expiry function |
| **U11** incident status rules and the recovery rule | GAP-07/08 remain open | `update_incident_status` |
| **A9** actor types, **A8-Q5** soft delete, **Q-X1** | Not part of Batch 2 | Actor columns, archiving |
| **A9-Q2** human-entered AI analysis | AI results are automation-only for now | – |
| **R13** action naming | Keep the database values; map labels in the app | UI only |
| **D-009** staging credentials and access | | Staging rehearsal |

## 8. Known limitations
- **The baseline matches the structure export and the recorded grants, not a fresh live dump.** It must be compared with a read-only schema dump of staging or production before the production step.
- **service_role grants and the live default privileges (P3b) aren't reproduced.** The baseline doesn't touch them, and the migrations grant explicitly.
- **Local tests ran on PostgreSQL 18 with a shim, not on Supabase's PostgreSQL 17 stack.**
- **The backend doesn't yet call the new functions** (release gate §1a). The machine endpoints aren't mounted yet. Their authentication middleware is ready and tested.
- **Hard-deleting an incident that has a decided approval or any timeline/automation history is refused**, for the owner too. This is intended (immutable decisions, A3/A7). Archiving needs A8-Q5.
- **Deleting a user who decided an approval** clears the approver link on the approval (FK `SET NULL`), but the decision itself and the audit entry naming them both stay.
- **Notification delivery claims** are "at least once": a delivery not recorded within 2 minutes is handed out again.
- **GAP-07/08 (incident transitions, recovery rule) remain open** until U11 is decided.
- **Owner changes without a JWT** (SQL Editor, migrations) are not written to the application audit log. They belong in the migration log.
- **Not yet verified on Supabase:** the definer functions rely on their owner owning the tables, so RLS doesn't block them. Local tests run as a superuser. Verify on staging (U13).
- **Review notes (low):** two simultaneous requests with the same idempotency key give the second caller DC409 rather than the existing run. `register_device_token` moves a known token to the caller. Cancelling a running run doesn't stop the n8n workflow. `start_playbook_run` doesn't re-check that the incident is still open. `machineAuth` signs `originalUrl`, query string included.
