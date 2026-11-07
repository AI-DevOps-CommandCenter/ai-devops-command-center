# Phase 19 – Final Database Verification Report

**Project:** AI-Powered Mobile DevOps Command Center
**Supabase project:** `devops-command-center` (ref `hjqvjztbsndgyooyadup`)
**Report date:** 2026-11-07
**Status:** Draft for review. No changes have been made to the live database.

> ## ⛔ IMPLEMENTATION BLOCKER
> **NO MIGRATION SQL OR LIVE DATABASE CHANGES UNTIL THESE ARCHITECTURE DECISIONS ARE APPROVED.**
> Decision status: **A1 APPROVED (2026-11-07)** · **A2–A7 PENDING**. The blocker stays in force until A2–A7 are also approved. See §10 and §11.

## How to read this report

Every finding carries a label:

| Label | Meaning |
|---|---|
| **[V-LIVE]** | Verified against the live database (read-only queries run by the project owner in the Supabase SQL Editor). |
| **[V-BACKUP]** | Verified by reading the local backup file `devops-command-center-backup.dump` (read-only, offline). |
| **[V-SCHEMA]** | Verified from the schema export `public-schema.sql`. |
| **[ASSUMPTION]** | Believed to be true but not proven. |
| **[RECOMMENDATION]** | Proposed action; requires approval. |
| **[DECISION NEEDED]** | Cannot proceed without a decision from the project owner. |

---

## 1. Sources and method

| Source | Details |
|---|---|
| Backup | `C:\AI-DevOps-CommandCenter\database-backups\devops-command-center-backup.dump` — pg_dump custom format, produced by pg_dump 18.6 from PostgreSQL 17.11, taken 2026-11-07. |
| Schema export | `C:\AI-DevOps-CommandCenter\database-backups\public-schema.sql` — `public` schema only, owners and privileges not included. |
| Live checks | Queries A–D (SELECT only), run in the Supabase SQL Editor by the project owner. |

The backup was read with a small offline parser (no database server, no `pg_restore`). It has **not yet been test-restored**.

---

## 2. Existing database structure [V-SCHEMA]

The `public` schema contains **18 tables**:

| # | Table | Rows (backup) | In target design? |
|---|---|---|---|
| 1 | profiles | 2 | Yes |
| 2 | services | 2 | Yes |
| 3 | deployments | 0 | Yes |
| 4 | incidents | 3 | Yes |
| 5 | incident_logs | 0 | **No** (target: `incident_events`) |
| 6 | investigations | 4 | Yes |
| 7 | ai_analyses | 0 | Yes |
| 8 | playbooks | 5 | Yes |
| 9 | playbook_runs | 1 | Yes |
| 10 | approvals | 1 | Yes |
| 11 | recovery_checks | 0 | Yes |
| 12 | notifications | 0 | Yes |
| 13 | device_tokens | 0 | Yes |
| 14 | integrations | 0 | Yes |
| 15 | audit_log | 0 | **No** (legacy duplicate of `audit_logs`) |
| 16 | audit_logs | 24 | Yes |
| 17 | postmortems | 3 | Yes |
| 18 | remediation_executions | 1 | **No** (overlaps `playbook_runs`) |

So: **15 tables exist in both**, **3 existing tables are not in the target** (`incident_logs`, `audit_log`, `remediation_executions`), and **3 target tables do not exist yet** (`incident_events`, `notification_deliveries`, `automation_runs`).

Other objects [V-SCHEMA / V-BACKUP]:

- Functions: `is_admin()`, `is_incident_manager()`, `admin_update_user_role()`, `handle_new_user()`, `set_updated_at()`, `rls_auto_enable()`. All `SECURITY DEFINER` functions set `search_path = ''` (good practice).
- Trigger `on_auth_user_created` on `auth.users` creates a `profiles` row on sign-up [V-BACKUP].
- Event trigger `ensure_rls` automatically enables RLS on new `public` tables [V-BACKUP].
- `updated_at` triggers on device_tokens, incidents, playbooks, postmortems, profiles, services.
- RLS is enabled on all 18 tables.
- Auth: both existing users have only the `email` identity provider. No GitHub identities exist yet [V-BACKUP].

---

## 3. Live verification results [V-LIVE]

### Query A – Status distribution

| Table | Status | Count |
|---|---|---|
| approvals | pending | 1 |
| incidents | investigating | 2 |
| incidents | open | 1 |
| investigations | completed | 2 |
| investigations | pending | 1 |
| investigations | running | 1 |
| playbook_runs | pending_approval | 1 |
| remediation_executions | succeeded | 1 |
| services | healthy | 2 |

This **matches** the status distribution extracted from the backup [V-BACKUP].

### Query B – Remediation vs approval

| Field | Value |
|---|---|
| Execution | `108d5a0d-078f-4834-9dcd-4ca6fe84919c` |
| Status | succeeded |
| Playbook | Test Restart Playbook (`requires_approval = false`) |
| Incident status | investigating |
| Approval on the same incident | pending |
| Recovery checks | 0 |

**Meaning:** a restart was recorded as successful while the only approval on that incident was still pending, and no recovery check was recorded. The database rules allowed this because the test playbook does not require approval.

### Query C – Playbook run vs approvals

| Field | Value |
|---|---|
| Playbook run | `e48ca6e7-81d6-4ab7-9c29-354b9d0127e7` |
| Status | pending_approval |
| approved_by | NULL |
| Playbook | restart (`enabled = false`) |
| Has an `approvals` row | **No** |

**Meaning:** the run waits for an approval that does not exist in the `approvals` table, and it points to a disabled playbook.

### Query D – Approval deadlock

| Field | Value |
|---|---|
| Approval | `fdea11c4-a8af-4741-9b2e-5caa95b620d6` |
| Requested by | `2f826d1c-8e0b-483c-9993-47a2d22ac62b` (the only admin) |
| Other admins | 0 |

**Meaning:** the approval rules require a *different* admin to decide. There is no other admin, so this request can never be approved or rejected.

---

## 4. Backup comparison limitations

What **is** established:

- All 18 `public` table row counts in the backup match the counts reported for the live database [V-BACKUP + owner-reported counts].
- Query A status distributions match between live and backup [V-LIVE + V-BACKUP].
- The specific records returned by Queries B, C and D exist in the backup with the same IDs and values [V-BACKUP].

What is **not** established:

- **Not every column of every row has been proven identical** between live and backup. Only counts, status distributions and the B–D records were compared.
- The backup has **not been test-restored**. Its usability is not proven.
- The schema export does **not** include grants or column privileges, and no table grants were found in the backup. **A restore from this backup would not reproduce live permissions.** Live table grants for all `public` tables were checked separately (P3, 2026-11-07; see §8 and the checklist). They must be re-applied on any restored copy.
- Supabase dashboard settings (Auth providers, GitHub OAuth, email templates, redirect URLs) are not in the backup.
- Data may have changed in the live database after the backup was taken.

[RECOMMENDATION] Before migration, run read-only per-table checksums on live and on a restored copy (see `SECURITY_AND_DATA_PRESERVATION_CHECKLIST.md`, section P).

---

## 5. Data consistency problems

| # | Finding | Evidence | Severity |
|---|---|---|---|
| D1 | A remediation succeeded while the approval on the same incident was pending. | Query B [V-LIVE] | High |
| D2 | A playbook run is `pending_approval` but has no `approvals` row. | Query C [V-LIVE] | High |
| D3 | The pending approval can never be decided (deadlock). | Query D [V-LIVE] | High |
| D4 | There is no database link between approvals and the action they approve. `approvals` only has `incident_id`. | [V-SCHEMA] | High |
| D5 | The pending approval (incident `6fc9b9e2…`) and the pending playbook run (incident `882078b5…`) are on **different incidents**, so they cannot belong together. | [V-BACKUP] | Info |
| D6 | The successful remediation has no recovery check, and its incident is still `investigating`. | Query B [V-LIVE] | Medium |
| D7 | None of the 3 incidents is linked to a service (`service_id` is NULL). They use free-text `service_name` values ("Payment Service", "Test Service"), and neither name exists in `services`. | [V-BACKUP] | Medium |
| D8 | All 3 postmortems belong to incidents that are not resolved. | [V-BACKUP] | Low |
| D9 | 2 incidents are `investigating` but have no `acknowledged_at`. | [V-BACKUP] | Low |
| D10 | Status words differ: `remediation_executions` uses `succeeded`, `playbook_runs`/`deployments` use `success`. `incidents.severity` allows `info`, `ai_analyses.severity` does not. | [V-SCHEMA] | Medium |
| D11 | "Requires approval" is stored twice: `playbooks.requires_approval` and `playbooks.configuration->approval_required`. The test playbook has only the column. | [V-BACKUP] | Low |
| D12 | JSON formats differ: one postmortem timeline uses `"10:00"`, others ISO timestamps. Action items use `priority` in one postmortem, `status` in another. | [V-BACKUP] | Low |
| D13 | Investigation `7d5ca2b2…` has been `running` since 2026-11-05. It may be stale. | [V-BACKUP] | Low |
| D14 | Audit history starts 2026-11-03 17:13:49 UTC. Creation of incident `6fc9b9e2…` (2026-11-02) is not audited. There are no audit entries for approvals or investigations. | [V-BACKUP] | Medium |
| D15 | Most records are test data (titles such as "RLS Security Test", "Audit Logging Test", "Test Restart Playbook", "Postmortem omission test"). | [V-BACKUP] | Info |
| D16 | Execution `108d5a0d…` has round, hand-set looking times (04:00:00 → 04:05:00) that are later than its `created_at`. | [V-BACKUP] / [ASSUMPTION] that these were set manually | Info |

### Records that look similar but are **not** duplicates (checked by ID and relationships)

- **Playbooks `restart` (`de8e209e…`) and `Test Restart Playbook` (`27041cdf…`)** both use `action_type = restart`. They have different IDs, configuration and approval settings, and each is referenced by a different record (the playbook run and the remediation execution). **Both must be kept.**
- **Two `PLAYBOOK_CREATED` audit entries named "Test Restart Playbook"** refer to two different playbook IDs: `523dc40f…` (later deleted; only the audit trail remains) and `27041cdf…` (still exists). **Not duplicates.**
- **Investigations `f6f96079…` and `b60a7855…`** are on the same incident with the same root cause and evidence, but have different IDs, summaries and creation times (15:00 vs 14:40). **Not proven duplicates**; flagged for manual review only.
- **`audit_log` vs `audit_logs`** are duplicate *tables* (same purpose). `audit_log` has 0 rows, so no records are at risk.

---

## 6. Security concerns

| # | Concern | Evidence | Severity |
|---|---|---|---|
| S1 | **Role self-escalation – not confirmed (resolved by check P3).** Policy `profiles_update_own` does not restrict columns. However, the live check showed `authenticated` has only SELECT on `public.profiles` (no INSERT/UPDATE/DELETE), and no column-level UPDATE on `role`. The policy is therefore inactive, and role changes only work through `admin_update_user_role()`. **This restriction must be preserved during migration.** Side effect: users also cannot update their own name directly. | P3 [V-LIVE], 2026-11-07 | Resolved – keep as requirement |
| S2 | **Potential approval-state forgery.** Policy "Users create own approval requests" (INSERT) only checks `requested_by = auth.uid()`. It does not itself enforce `status = 'pending'` or `approver_id IS NULL`, and `authenticated` has the INSERT grant (P3). Risk requiring constraint/trigger/function review; **not a confirmed exploit**. | Policy [V-LIVE, P7]; exploitability not verified | High (potential) |
| S3 | **Workflow authorization risk on playbook runs.** The INSERT policy does not constrain `status`, `approved_by` or `approved_at`. Managers can UPDATE any run, and the policy does not require a corresponding approved `approvals` record (it only checks `approved_by IS NULL OR approved_by <> requested_by`). Needs database constraints/functions and a backend review. | Policy [V-LIVE, P7] | **High priority** |
| S4 | **Remediation without approval checks.** `remediation_executions` insert/update policies check the manager role only. `triggered_by` is not bound to the caller. Legacy table; preserve its record and review its migration into `playbook_runs`. | Policy [V-LIVE, P7] | High |
| S5 | **Audit-integrity risk.** Authenticated users can INSERT audit rows when `actor_id = auth.uid()`. They can therefore create audit entries under their own identity, with any action, entity and details. Target: trusted audit-writing function only, no direct client INSERT. | Policy [V-LIVE, P7] | Medium |
| S6 | **History can be destroyed by cascades.** Deleting an incident deletes its approvals, playbook runs, executions, investigations and postmortems (`ON DELETE CASCADE`). This conflicts with "immutable approvals" and "safe preservation of historical records". | [V-SCHEMA] | High |
| S7 | **Audit is not append-only.** There is no trigger blocking UPDATE/DELETE. The service-role key bypasses RLS. `audit_logs.actor_id … ON DELETE SET NULL` rewrites audit rows if a profile is deleted. | [V-SCHEMA] | Medium |
| S8 | **Backend uses the service-role key**, which bypasses all RLS. Authorization must be enforced by the backend or by database functions/triggers. | `backend/src/lib/supabase.ts` references the service role | Medium |
| S9 | Postmortem insert does not bind `created_by` to the caller. | [V-SCHEMA] | Low |
| S10 | Six tables have RLS enabled but **no policies** (`services`, `deployments`, `ai_analyses`, `notifications`, `recovery_checks`, `audit_log`), and `authenticated` has no direct grants on them (P3). App users have no access (safe, but not functional). service_role access was not assessed by this audit. | [V-LIVE, P3 + P7] | Info |
| S14 | **Device-token integration gap.** `device_tokens` has own-row SELECT/INSERT/DELETE policies, but `authenticated` has no table grant, so the policies have no effect and clients cannot register push tokens directly. Functional gap, not a security flaw. | [V-LIVE, P3 + P7] | Medium (functional) |
| S11 | `profiles` has two overlapping SELECT policies. | [V-SCHEMA] | Info |
| S12 | `integrations.settings` is free JSON. [ASSUMPTION] It could be used to store tokens in plain text. | [V-SCHEMA] | Medium |
| S13 | GitHub sign-up risk: `profiles.email` is UNIQUE. If GitHub sign-in creates a separate auth user with an email that already exists, `handle_new_user()` would fail and block sign-up. | [V-SCHEMA]; behaviour **[ASSUMPTION]**, must be tested | Medium |

---

## 7. Duplicate and legacy tables

| Existing table | Status | Reason | Proposed handling |
|---|---|---|---|
| `audit_log` (0 rows) | Legacy duplicate | Same purpose as `audit_logs`, no policies, unused. | Retain temporarily, then rename as deprecated, drop only after approval. |
| `incident_logs` (0 rows) | Legacy / replaced | Target uses `incident_events`. | Retain temporarily; map columns; retire after approval. |
| `remediation_executions` (1 row) | Legacy / overlapping | Not in target; overlaps `playbook_runs`. | Copy its 1 record into the target (see mapping); keep the original table read-only until sign-off. |
| `investigations` vs `ai_analyses` | Overlapping, **both in target** | Overlapping columns. | Keep both; link `ai_analyses` to `investigations`. Do not merge. |
| `approvals` vs `playbook_runs.approved_by/status` | Overlapping mechanisms | Two places record approval. | `approvals` becomes the only source of decisions, linked to `playbook_runs`. |

---

## 8. Conclusion

- The live database and the backup agree on all counts and status distributions checked. Full row-by-row equality is **not** proven.
- No foreign-key orphans exist (all FKs are enforced) [V-SCHEMA].
- Four workflow inconsistencies (D1–D4) and several security gaps (S1–S7) must be fixed by design before the database is used beyond testing.
- S1 was checked on live (P3): `authenticated` cannot update `profiles`, so self-role-escalation is not possible today. Keep it that way.
- **Table-grant baseline (P3, 2026-11-07) [V-LIVE]:**

  | Table | `authenticated` privileges |
  |---|---|
  | approvals | INSERT, SELECT, UPDATE |
  | audit_logs | INSERT, SELECT |
  | incident_logs | INSERT, SELECT |
  | incidents | INSERT, SELECT, UPDATE |
  | integrations | DELETE, INSERT, SELECT, UPDATE |
  | investigations | INSERT, SELECT, UPDATE |
  | playbook_runs | INSERT, SELECT, UPDATE |
  | playbooks | DELETE, INSERT, SELECT, UPDATE |
  | postmortems | INSERT, SELECT, UPDATE |
  | profiles | SELECT |
  | remediation_executions | INSERT, SELECT, UPDATE |

  - `anon`: no direct table grants were returned.
  - `authenticated` has no direct grant on `ai_analyses`, `audit_log`, `deployments`, `device_tokens`, `notifications`, `recovery_checks`, `services`.
  - **GRANT alone does not establish effective access.** RLS policies must also allow the operation, so grants and policies have to be reviewed together.
  - **Security review points (not confirmed vulnerabilities):**
    - approvals: replace client INSERT/UPDATE with controlled approval functions.
    - audit_logs: restrict direct client INSERT to a trusted audit-writing function.
    - integrations and playbooks: admin-only management.
    - playbook_runs: clients must not directly control status or approval fields.
    - remediation_executions: preserve existing records and review its migration into the canonical `playbook_runs` model.
  - These grants show that the policy concerns S2–S5 (§6) are reachable through client grants. Whether each one is actually exploitable depends on the combined grant + RLS review in stages 6–7.
- **RLS policy inventory (P7, 2026-11-07) [V-LIVE]:** 31 permissive policies on 12 tables, all for role `authenticated`. The full inventory (names, commands, USING and WITH CHECK) is in the checklist, P7.
  - Permissive policies for the same command combine with **OR**. Effective access requires the GRANT (P3) **and** a matching policy.
  - **approvals:** INSERT allowed when `requested_by = auth.uid()`. The policy does not enforce `pending`/`approver_id IS NULL`, so potential approval-state forgery is a review item, not a confirmed exploit (S2).
  - **playbook_runs:** a high-priority workflow authorization risk (S3). INSERT does not constrain status or approval fields; manager UPDATE does not require an approved approval record.
  - **audit_logs:** users can insert entries under their own identity, an audit-integrity risk (S5).
  - **profiles:** `profiles_update_own` exists but has no effect, because there is no UPDATE grant. **Not** a confirmed live vulnerability (S1).
  - **device_tokens:** policies without a grant, a functional integration gap (S14).
  - **integrations, playbooks:** admin-only management matches the target. Enabled playbooks are readable by authenticated users.
  - **No policies:** ai_analyses, audit_log, deployments, notifications, recovery_checks, services. There are no `authenticated` grants either. service_role access is not inferred.
  - **incidents, incident_logs, investigations, postmortems, remediation_executions:** ownership/manager checks are compared with the target matrix in checklist P7 (7h). Main difference: users can currently create investigations for their own incidents, while the target is read-only for users.
  - **Open check:** the policy expression text in P7 was transcribed from `public-schema.sql`. It still needs a character-level comparison against the raw live `pg_policies` rows.
- Default privileges were checked on live (P3b) [V-LIVE]:
  - For objects created by `supabase_admin`, new tables, sequences and functions get broad access for `anon`/`authenticated`.
  - For objects created by `postgres`: tables `{postgres=arwdDxtm/postgres,anon=Dxtm/postgres,authenticated=Dxtm/postgres,service_role=arwdDxtm/postgres}`, sequences `{postgres=rwU/postgres}`, functions `{postgres=X/postgres}`.
  - `Dxtm` means TRUNCATE, REFERENCES, TRIGGER and MAINTAIN. It does **not** include SELECT, INSERT, UPDATE or DELETE.
  - So: new tables created by `postgres` give app users no read/write access, but do give them TRUNCATE, which RLS does not stop. New functions created by `postgres` are not callable by app users until EXECUTE is granted.
  - New tables and functions must get explicit grants and EXECUTE permissions during migration. Which defaults apply depends on the migration role (decision U13).
- EXECUTE permissions on the **existing** functions were checked on live (P3c, 2026-11-07) [V-LIVE]:

  | Function | anon | authenticated | SECURITY DEFINER |
  |---|---|---|---|
  | admin_update_user_role | false | true | true |
  | handle_new_user | true | true | true |
  | is_admin | false | true | true |
  | is_incident_manager | false | true | true |
  | rls_auto_enable | true | true | true |
  | set_updated_at | true | true | false |

  - Being able to execute a function is **not** a vulnerability on its own. No function is classed as vulnerable from this result.
  - `admin_update_user_role` must keep its internal admin authorization checks.
  - `is_admin` and `is_incident_manager` must stay executable by `authenticated`, because RLS policies depend on them.
  - `handle_new_user`, `rls_auto_enable` and `set_updated_at` are trigger-related. Unnecessary client EXECUTE should be reviewed and restricted, after testing on the rehearsal copy that the triggers keep working.
  - New functions must have explicit EXECUTE permissions.

See also: `MIGRATION_MAPPING.md`, `MIGRATION_EXECUTION_PLAN.md`, `SECURITY_AND_DATA_PRESERVATION_CHECKLIST.md`.

---

## 9. Backend code security audit (2026-11-07)

**Scope and method.** This was a read-only review of the backend code on three git branches, read with `git show` without checking anything out. No application code was changed, no database writes were made, and Supabase was not modified.

| Branch | Database access | Relevant content |
|---|---|---|
| `feature/backend-api` (checked out) | **service_role** key | Services and password-reset routes only. |
| `origin/feature/backend-api-database` (last commit 2026-11-05) | Publishable key **plus the user's login token** (RLS applies) | Approvals, playbook runs, remediation, audit, admin. |
| `origin/feature/notifications` | **service_role** key | Push-notification service. |

`B` below = `origin/feature/backend-api-database:backend/src`. Line numbers refer to that branch's files.

Findings are grouped into four separate categories, which must not be mixed:

### 9.1 Verified live database findings [V-LIVE]

| # | Finding | Source |
|---|---|---|
| L1 | No user-created triggers on `approvals`, `playbook_runs`, `remediation_executions`, `audit_logs`. | Owner's live audit, 2026-11-07 |
| L2 | No database constraint enforces: approvals inserted as `pending`; `approver_id <> requested_by`; a playbook run having a valid approval record before entering an approved state; remediation being linked to a valid approval decision; audit-log immutability. | Owner's live audit, 2026-11-07 |
| L3 | `authenticated` has INSERT/SELECT/UPDATE on `approvals`, `playbook_runs`, `remediation_executions`, and INSERT/SELECT on `audit_logs`. | P3 |
| L4 | The `approvals` INSERT policy checks only `requested_by = auth.uid()`. The `playbook_runs` INSERT policy does not constrain `status`, `approved_by`, `approved_at`. Manager UPDATE on `playbook_runs` does not require an approved approval record. | P7 (7a, 7b) |
| L5 | `authenticated` can INSERT `audit_logs` rows with `actor_id = auth.uid()`. There are no client UPDATE/DELETE grants or policies on `audit_logs`. | P3, P7 (7c) |
| L6 | `device_tokens` columns include `device_token` and `platform`. There is no `notifications_log` table. | [V-SCHEMA] (schema export) |

These are **database-level gaps**, not confirmed exploits.

### 9.2 Verified backend code findings [V-CODE]

| # | Finding | Evidence |
|---|---|---|
| C1 | **Approval creation through the backend is pending-only.** The controller reads only `incident_id`; the service hard-codes `status: "pending"` and `requested_by: userId`. | `B/controllers/approval.controller.ts:27`; `B/services/approval.service.ts:32-38` |
| C2 | **Approval decision:** the backend checks for the admin role only. There is no explicit self-approval check in code; separation relies on the RLS policy. | `B/controllers/approval.controller.ts:196-203`; `B/services/approval.service.ts:92-103` |
| C3 | **Different approval authority.** `approvals` decisions are admin-only. `playbook_runs` decisions are admin **or operator**. Deciding a playbook run never reads or writes `approvals`. | `B/controllers/approval.controller.ts:198`; `B/controllers/playbook-run.controller.ts:264-271`; `B/services/playbook-run.service.ts:133-144` |
| C4 | **Auto-approved runs.** A playbook with `requires_approval = false` produces a run whose initial status is `approved`. | `B/services/playbook-run.service.ts:57-60` |
| C5 | **The enabled-playbook check exists only in the backend** (not in the database). | `B/services/playbook-run.service.ts:39-41` |
| C6 | **Remediation does not verify an authoritative approval record.** Create checks only the admin/operator role: there is no lookup of `approvals`, playbook `enabled` or `requires_approval`, and `playbook_id` may be null. Update accepts any status (including `pending → succeeded`) and any client-supplied `started_at`/`completed_at`. | `B/controllers/remediation-execution.controller.ts:60-104, 291-376`; `B/services/remediation-execution.service.ts:40-49, 105-115` |
| C7 | **Playbook-run status endpoint is not routed.** `updatePlaybookRunStatusController` exists but no route registers it, and it does not consult `approvals` either. | `B/routes/playbook-run.routes.ts:30-32`; `B/services/playbook-run.service.ts:173-180` |
| C8 | **Best-effort audit logging.** Audit writes are wrapped in try/catch and failures are only logged, so the action succeeds even if no audit entry is written. The code has no audit update/delete path. | e.g. `B/controllers/approval.controller.ts:46-61, 244-264`; `B/controllers/playbook-run.controller.ts:101-118`; `B/services/audit.service.ts:15-23, 45-49` |
| C9 | **Identity is verified server-side.** The login token is checked with `supabase.auth.getUser`, and `userId` comes from the verified token. Roles are read from `profiles`. | `B/middleware/auth.ts:41-57`; `B/services/approval.service.ts:9-24`; current branch `backend/src/middleware/auth.ts:28-66` |
| C10 | **The two backend branches use different Supabase access architectures.** The current branch uses the service_role client (bypasses RLS; backend checks are the only control). `backend-api-database` uses the publishable key with the user's token (RLS enforced; backend checks are extra). | `backend/src/lib/supabase.ts:7,15-23`; `B/config/supabase.ts:6,13-37` |
| C11 | **Current-branch service_role routes are authenticated and role-checked.** Every services route requires login (`router.use(requireAuth)`); POST/PATCH/DELETE also require admin or operator. | `backend/src/routes/services.routes.ts:9, 72, 142, 275` |
| C12 | **Notifications service uses service_role without route authentication.** No route requires login. `/register-token` takes `userId` from the request body. `/dispatch-alert`, `/request-approval`, `/dispatch-recovery` and `/history` are open. | `origin/feature/notifications:notifications/src/services/supabase.service.ts:11,15`; `notifications/src/routes/notifications.routes.ts:9-14, 75-183`; `notifications/src/server.ts:13-17` |
| C13 | **Notifications service names don't match the live schema.** It writes `device_tokens` columns `fcm_token`, `device_type`, `device_model`, `last_updated_at`, and a table `notifications_log`, none of which exist (see L6). | `origin/feature/notifications:notifications/src/services/supabase.service.ts:30-41, 84, 96-100` |
| C14 | **No n8n webhook endpoint exists in any backend branch.** The n8n branch has only `docker-compose.yml`, a prompt and a schema (`automation/workflows/` contains only `.gitkeep`). `N8N_WEBHOOK_SECRET` is configured, but no code verifies it. | `origin/feature/n8n-incident-workflow:automation/docker-compose.yml:12-19` |
| C15 | The current branch returns the (public) publishable/anon key at `/api/auth/config`. | `backend/src/routes/auth.routes.ts:8-23` |

### 9.3 Inferences (derived, not executed or proven)

| # | Inference | Based on |
|---|---|---|
| I1 | **Direct approval insertion can bypass the intended pending-only workflow.** A logged-in user calling the Supabase API directly (with their own token and the public key) could insert an approval with `status = 'approved'` and any `approver_id`. **Derived from grants, policies and the absence of triggers/constraints. Not tested or executed.** | L1–L4, C10, C15 |
| I2 | **Direct playbook-run insertion can create already-approved runs,** including for a disabled playbook, because the database does not check status or enabled state on insert. **Not tested or executed.** | L2–L4, C5 |
| I3 | A manager who requested a run could update it directly with `approved_by` set to another user's ID, which passes the current policy. **Not tested.** | L4 |
| I4 | **Backend-only rules give no independent protection** on the `backend-api-database` architecture, because clients can reach the database directly: pending-only insert, enabled check, status transitions, field locks. Only grants and RLS apply on every path. | C1, C5, C6, C10 |
| I5 | The live audit entries were most likely written by the `backend-api-database` code (the action names match). | §5 D14, C8 |
| I6 | The hand-set looking timestamps on remediation `108d5a0d…` are consistent with the update endpoint accepting client-supplied times. | D16, C6 |

### 9.4 Needs further verification

| # | Item |
|---|---|
| N1 | **n8n:** the workflows in the running n8n instance, how they authenticate (webhook secret checks), and which credentials they hold (user token, operator account, or service_role). |
| N2 | Which backend branch is deployed or will be merged (see A1). |
| N3 | Whether the notifications service is deployed or reachable, and on which network. |
| N4 | Confirm I1–I3 by testing **on the rehearsal copy only**, never on live. |
| N5 | Whether any client app or other service also connects to Supabase directly. |

---

## 10. Architecture decisions required

> **⛔ NO MIGRATION SQL OR LIVE DATABASE CHANGES UNTIL THESE ARCHITECTURE DECISIONS ARE APPROVED.**

| # | Decision | Status | Why it blocks | Related |
|---|---|---|---|---|
| A1 | **Canonical backend branch:** `feature/backend-api` or `origin/feature/backend-api-database`, or a merge of the two. | **APPROVED 2026-11-07** – hybrid architecture on base `origin/feature/backend-api-database`; see §11 | Determines which code the database must protect and which routes exist. | C10, N2 |
| A2 | **User-token/RLS architecture vs service-role/backend-only architecture.** | **PENDING** – A1 sets user-token + RLS as the primary model. A2 still has to define the "controlled privileged mechanism" for server-side operations (which operations, which identity, how it is authorized) and confirm the final grant/RLS boundary. | With user tokens, RLS and database functions are the security boundary and must enforce the workflow (I4). With service_role, the backend is the only control, and clients must be blocked from direct table writes. | C10, I1–I4 |
| A3 | **Canonical approval authority and authorized approver roles:** one approval system (`approvals` linked to `playbook_runs`) and who may decide (admin only, or admin + operator). | **PENDING** | Two inconsistent systems exist today. | C2, C3, U2, U3 |
| A4 | **No-approval playbook execution rules:** whether `requires_approval = false` may auto-approve, and for which action types. | **PENDING** | Auto-approval exists in code. | C4, U4, U5 |
| A5 | **Secure n8n integration identity:** a dedicated role, a backend endpoint, or a service account; plus the webhook authentication method. | **PENDING** (A1 principle: dedicated limited identity, authenticated machine-to-machine requests, no service_role) | Unknown today; n8n must never be able to decide approvals. | C14, N1, U9 |
| A6 | **Notifications authentication and database compatibility:** route authentication, user identity taken from the login token, whether service_role is justified, and table/column names aligned with the schema. | **PENDING** (A1 principle: dedicated limited identity, no service_role) | Open endpoints with service_role; writes would fail against the live schema. | C12, C13, N3 |
| A7 | **Trusted audit logging:** audit writes through a trusted database function, no direct client INSERT, and whether audit failure must fail the action. | **PENDING** | Entries can be user-created and logging can silently fail. | L5, C8, §W8 |

---

## 11. Architecture decision record – A1 (APPROVED)

**Status:** **APPROVED** by the project owner on 2026-11-07.
**Implementation status:** **NOT IMPLEMENTED.** This records a decision only. No code has been merged, ported or changed, and no database change has been made.

### 11.1 Approved decision

**Adopt a hybrid backend architecture, using user-token + Supabase RLS as the primary database security model.**

1. **Canonical backend base:** `origin/feature/backend-api-database`.
2. **Features to port from `feature/backend-api`:**
   - Authentication and profile validation middleware.
   - Reusable role-based authorization middleware.
   - Zod input validation.
   - Helmet security headers.
   - Vitest and Supertest testing setup.
   - Password reset functionality, after reviewing its redirect configuration (currently hard-coded to `http://localhost:3000/reset-password`, `backend/src/routes/auth.routes.ts:47`).
3. **Database access:**
   - Use the Supabase publishable key with the authenticated user's JWT.
   - Enforce database access through Supabase RLS and explicit grants.
   - Never expose the service_role key to Flutter or n8n.
   - Any privileged server-side operation must use a carefully controlled and explicitly authorized mechanism.
4. **Security enforcement:**
   - Backend authorization checks are an additional layer.
   - Database constraints, RLS policies and trusted database functions enforce critical workflow rules.
   - Approval, remediation and audit operations must not rely solely on frontend or backend checks.
5. **n8n and notifications:**
   - Use dedicated, limited identities.
   - Authenticate machine-to-machine requests.
   - Do not share service_role credentials with n8n or notification services.

### 11.2 Rationale

- `origin/feature/backend-api-database` already implements most of the domain: incidents, investigations, approvals, playbook runs, remediation, postmortems, admin, audit and dashboard [V-CODE]. It is consistent with the live data and RLS design (inference I5).
- **Least privilege:** each request acts with the calling user's rights, so a backend defect cannot exceed them. With service_role, any missing check exposes the whole database.
- Clients can reach the database directly with their own token (C10, C15, I4), so database-level enforcement is needed whichever architecture is used. Making RLS, constraints and trusted functions authoritative matches the Phase 19 design (checklist §W).
- The quality components of `feature/backend-api` (middleware, zod, helmet, tests, password reset) are small and portable [V-CODE].

### 11.3 Rejected alternative

**service_role / backend-only architecture** (`feature/backend-api` as base, all direct client table grants removed). Rejected because:
- the backend would become the single security control;
- the service_role key would grant full access if compromised;
- the 31 existing RLS policies would be bypassed;
- most of the domain features would have to be re-implemented on that base.

### 11.4 Approved decision vs proposed implementation details

| Approved (A1) | Proposed implementation details – **not yet approved, not implemented** |
|---|---|
| Base branch `origin/feature/backend-api-database` | How the branches are reconciled (both create `backend/package.json`, `server.ts`, `middleware/auth.ts`); merge base `9aa3a0d`. |
| Port the listed features from `feature/backend-api` | Order of porting; fixing the duplicate `"type"` key in that branch's `package.json`; adding `test`/`typecheck` scripts. |
| Publishable key + user JWT; RLS + explicit grants | Exact grants and policies per table (stage 7, §R1), including tables that currently have no client access (`services`, `device_tokens`, `notifications`, `recovery_checks`, `ai_analyses`). |
| Critical workflow rules enforced in the database | Specific functions, triggers and constraints (checklist §W). These depend on A3, A4 and A7. |
| A controlled mechanism for privileged server-side operations | Its form and identity – **open under A2**. |
| Dedicated limited identities for n8n and notifications | Concrete identity and authentication method – **open under A5 and A6**. |

### 11.5 Effect on the audit findings

All findings in §5–§9 remain valid and unchanged. A1 does not fix any of them. It determines **where** the fixes must live: in the database (RLS, grants, constraints, trusted functions), with backend checks as an additional layer.

> **⛔ NO MIGRATION SQL OR LIVE DATABASE CHANGES UNTIL A2–A7 ARE ALSO APPROVED.**
