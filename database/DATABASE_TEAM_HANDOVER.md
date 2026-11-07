# Database Team Handover

**Project:** AI-Powered Mobile DevOps Command Center
**Date:** 2026-11-07
**Branch:** `feature/database-implementation` (local commits, not pushed)

> **Status in one line:**
> - **Done, tested locally:** the verified baseline and the additive structure.
> - **Blocked on decisions A2–A7:** the database workflow and security logic.
> - **Not yet done:** staging rehearsal and the production migration.
>
> **The database is NOT complete.**

---

## 1. What you can start developing against NOW

| Team | Start now | Contract |
|---|---|---|
| **Mobile (Flutter)** | <ul><li>Sign in with Supabase Auth (email/password) to get the access token.</li><li>Call the backend with `Authorization: Bearer <token>`.</li><li>Build screens on the current endpoints: dashboard, incidents, investigations, approvals, playbook runs, postmortems, admin.</li><li>Poll for status changes.</li></ul> | `API_AND_INTEGRATION_CONTRACTS.md` Part A (verified) and the §A.4 models |
| **Backend** | <ul><li>New endpoints use `validate()` (Zod), `requireRole()` and the per-request user client.</li><li>Add contract tests (see `backend/tests`).</li><li>Keep using the user's JWT; no service_role (D-001).</li></ul> | `backend/README.md`, Part A |
| **n8n** | <ul><li>Draft workflows against **mock** machine endpoints.</li><li>The AI output schema already matches `ai_analyses`.</li><li>Don't put service_role or a database URL in n8n.</li></ul> | Part B.3 (proposed; final after A5) |
| **Notifications** | Wait. The code location is unknown (R6) and the design is pending A6. | Part B.4 (proposed) |

**Don't build against yet:** the proposed database functions (Part B.2). Their names and shapes may change when A2–A7 are approved.

---

## 2. Schema overview

21 `public` tables: 18 live, verified, plus 3 new target tables.

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

### Role and permission matrix (current; verified by tests 02, 05, 06)

| Action | anon | user | operator | admin |
|---|---|---|---|---|
| Read own profile / all profiles | – | own | own | all |
| Change roles | – | – | – | others only (function) |
| Create incident | – | own | own | own |
| Read incidents | – | own | all | all |
| Update incidents | – | – | ✓ | ✓ |
| Request approval | – | own | own | own |
| Decide approval | – | – | – | ✓ (not own) |
| Request playbook run | – | own incident | ✓ | ✓ |
| Decide playbook run | – | – | ✓ (not own) | ✓ (not own) |
| Record remediation execution | – | – | ✓ | ✓ |
| Read audit logs | – | – | – | ✓ |
| Manage playbooks / integrations | – | – | – | ✓ |
| Delete incidents | – | – | – | – (no grant) |

---

## 3. Migrations (in order)

| # | File | Kind | Status |
|---|---|---|---|
| 1 | `supabase/migrations/20261107000000_baseline_live_public_schema.sql` | Baseline of the verified live schema, with grants and the two database-level triggers | Tested locally. **Not to be executed on production**: there it is only *marked* as applied, in a separately approved step. |
| 2 | `20261107000100_add_missing_fk_indexes.sql` | 10 indexes | Tested locally |
| 3 | `20261107000200_create_target_tables.sql` | 3 new tables, no client access | Tested locally |
| 4 | `20261107000300_add_target_link_columns.sql` | 5 nullable link columns | Tested locally |

- **Rollback:** `database/rollback/<migration>.down.sql`. Apply in reverse order. Each script refuses to run if it would destroy data.
- **Historical SQL** (`origin/feature/database:database/schema.sql`, `001_align_with_proposal.sql`) is unchanged and is **not** a baseline (D-008).

**Not implemented (waiting for decisions):** all workflow functions and triggers, RLS and grant changes, audit hardening, approval link and statuses, the `automation` role, actor types, soft delete. See §7.

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
- **8 test files, 179 assertions, 0 failures.**
- **Data preserved** across migrations, rollback and re-apply (46 synthetic rows, byte-identical checksums).
- **Rollback guard works.**
- **Production is PostgreSQL 17.** Staging rehearsal (P7) must repeat the run on 17.

| Suite | Covers |
|---|---|
| 01 | Baseline structure, ensure_rls behaviour, triggers |
| 02 | Grants equal the live baseline (P3/P3c) |
| 03 | CHECK/UNIQUE/FK behaviour (incl. current CASCADE, SET NULL) |
| 04 | Sign-up trigger, `updated_at`, role function |
| 05 | RLS per role, anon, tables without access |
| 06 | Approval rules: self-approval blocked, admin-only, decided is final, deadlock |
| 07 | **Known gaps** GAP-01…10 (pass today; flip when A2/A3/A4/A7 are implemented) |
| 08 | New tables: no client access, duplicate n8n execution blocked, statuses, links, indexes |

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
2. Apply migrations 2–4.
3. Verify the 46 production records.

---

## 7. Remaining decisions (blocking the database logic)

Full list in `DATABASE_DECISION_REGISTER.md` §7. **Team-leader approval needed** for the items below.

| Decision | Why it matters | Recommendation (not approved) | Blocks |
|---|---|---|---|
| **A2** boundary (Q2–Q5) | Rules enforced only in the backend can be bypassed (GAP-01/02) | Revoke direct client writes on workflow and audit tables; definer functions for transitions; constraints/triggers for simple invariants | All workflow functions, the RLS/grant migration |
| **A3** approval model | Two approval paths; remediation without approval (GAP-06) | One model: `approvals.playbook_run_id`; admin + operator approve, never own; operators may complete runs manually with a reason; 24 h expiry, 30 min timeout | Workflow functions, approval statuses |
| **A4** no-approval rules | An enabled restart needs no approval | Allow-list, everything protected by default; all four current action types protected | `request_playbook_run` |
| **A5** n8n identity | Machine access without service_role | `automation` role; the backend holds that identity; HMAC both ways | Machine endpoints, `start/complete` functions, automation_runs access |
| **A6** notifications | Code missing (R6); no client grants | Fold into the backend; push + in_app first | Notification functions, device-token access |
| **A7** audit / timeline | Audit is forgeable and best-effort (GAP-05/09) | Fail closed; no FK, stored actor reference; append-only + TRUNCATE guard; triggers for direct writes; mark the 24 old rows legacy | Audit hardening, incident_events access |
| **Q-X1** (A8–A10) | Reconciliation, actor model, deployment process | Accept | Soft delete, actor types, legacy copy (U1) |
| **R13** action naming | Brief uses `restart_service`…, database uses `restart`… | Keep the database values; map labels in the app (no data change) | Nothing (UI only) |

**Independent work already done without these decisions:** baseline, indexes, target tables, link columns, tests, contracts.

## 8. Known limitations
- **The baseline matches the structure export and the recorded grants, not a fresh live dump.** It must be compared with a read-only schema dump of staging or production before the production step.
- **service_role grants and the live default privileges (P3b) aren't reproduced.** The baseline doesn't touch them, and the migrations grant explicitly.
- **Local tests ran on PostgreSQL 18 with a shim, not on Supabase's PostgreSQL 17 stack.**
- **The backend doesn't yet use the new tables or link columns.**
- **Clients with table-level UPDATE on `playbook_runs` (managers) can write `automation_run_id`** until A2-Q3 revokes direct writes.
- **The known gaps GAP-01…10 remain open until A2/A3/A4/A7 are implemented.**
