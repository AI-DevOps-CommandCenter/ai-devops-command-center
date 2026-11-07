# Migration Execution Plan

**Status:** Draft for review. **Do not start implementation until the owner approves this plan.**
**Scope:** Move the existing `public` schema to the approved 18-table target design without losing or rewriting existing records.

Related documents: `PHASE19_FINAL_VERIFICATION_REPORT.md`, `MIGRATION_MAPPING.md`, `SECURITY_AND_DATA_PRESERVATION_CHECKLIST.md`.

> ## ⛔ IMPLEMENTATION BLOCKER
> **NO MIGRATION SQL OR LIVE DATABASE CHANGES UNTIL THESE ARCHITECTURE DECISIONS ARE APPROVED.**
> Decisions A1–A7 (see "Architecture decisions" at the end, and report §10) must be approved before stage 1 can be completed. Stage 3 onwards cannot start until they are.

---

## Principles

- **Never rehearse on live.** Stages 3–11 run first on a restored copy (local Postgres 17 or a separate Supabase staging project/branch). Only stage 13 touches production.
- **Additive before restrictive.** Create → copy → validate → *then* add triggers, constraints and RLS that would reject legacy data.
- **Every stage has a gate.** A stage starts only when the previous gate has passed and been recorded.
- **Nothing is dropped** in this migration. Legacy-table retirement is a separate, later approval.

## Stage dependency overview

```
0 Architecture decisions A1–A7 (BLOCKING)
      │
1 Finalize schema
      │
2 Verify backup + test restore ──────────────► 12 Rollback strategy (designed here, used in 13)
      │
3 Create tables + additive columns
      │
4 Backfill / map data
      │
5 Validate FKs + constraints
      │
6 Functions + triggers
      │
7 RLS policies + grants
      │
8 Auth/authorization tests ─┐
9 Approval/remediation tests├─(8 → 9 → 10 in order)
10 n8n integration tests ───┘
      │
11 Validate records + counts
      │
13 Production migration (requires 2, 11, 12 complete and owner sign-off)
```

---

## Stage 0 – Approve architecture decisions (blocking)

**Purpose:** Settle how the application reaches the database, because that decides where security must be enforced.

The backend code audit (report §9) found two backend branches with different Supabase access architectures (C10). It also found inconsistent approval authority (C3), remediation without an approval check (C6), best-effort audit logging (C8), an unauthenticated notifications service using service_role (C12, C13), and no verified n8n integration identity (C14, N1). The design of stages 1, 6 and 7 depends on these answers:
- If clients use user tokens directly (RLS architecture), the database functions, triggers and policies must enforce the whole approval workflow.
- If only the backend uses service_role, client table grants must be removed and the backend becomes the security boundary.

**Gate:** decisions A1–A7 approved and recorded by the owner. **No migration SQL or live database change before this gate.**
**Why first:** stage 1 (schema), stage 6 (functions/triggers) and stage 7 (RLS/grants) are designed differently under each architecture.

## Stage 1 – Finalize target schema

**Purpose:** Turn the approved 18-table list into a full column-level design.

Tasks:
- Resolve every [DECISION NEEDED] item in `MIGRATION_MAPPING.md` (see "Unresolved decisions" below).
- Confirm the proposed columns for the 3 new tables and the new link columns.
- Confirm status vocabularies per table.
- Confirm FK delete behaviour (RESTRICT vs CASCADE) for every relationship.
- Confirm the role permission matrix (see checklist §R).

**Gate:** owner sign-off on the written column-level design.
**Why first:** every later stage depends on these choices. Changing them later means repeating stages 3–11.

## Stage 2 – Verify backup and perform a test restore

Tasks:
- Take a **fresh** backup immediately before rehearsal (custom format + schema-only + data-only), **including roles and grants**. The current schema export omits privileges.
- Record a SHA-256 hash of each backup file.
- Restore into an isolated environment using `pg_restore` **18.x** (the archive was written by pg_dump 18.6; older `pg_restore` cannot read it).
- Compare the restored copy with live: row counts for all 18 tables plus per-table checksums (read-only queries; see checklist §P).
- Capture current grants and column privileges from live (read-only) for **all** tables, plus default privileges (P3b). `profiles` is already recorded (P3). Re-apply them on the restored copy, because the backup contains no grants.

**Gate:** restore succeeds; counts and checksums match live; grants captured.
**Dependency:** stage 3 rehearsal runs on this restored copy. Stage 12 rollback depends on this backup being proven restorable.

## Stage 3 – Create missing tables and additive columns

On the restored copy only:
- Create `incident_events`, `notification_deliveries`, `automation_runs`.
- Add the new **nullable** link and metadata columns (e.g. `approvals.playbook_run_id`, `playbook_runs.legacy_source`, `recovery_checks.playbook_run_id`, `ai_analyses.investigation_id`).
- Add new allowed status values (e.g. approvals `cancelled`/`expired`, ai_analyses severity `info`). Removing values is not allowed.
- **Do not** add NOT NULL, new CHECK rules that existing rows break, validation triggers, or new RLS yet.
- Note: the `ensure_rls` event trigger will enable RLS on the new tables automatically, so they are locked until stage 7. That is the intended safe default.
- **Default privileges [V-LIVE, P3b]:** if `postgres` creates the new tables, `anon`/`authenticated` automatically receive `Dxtm` (TRUNCATE, REFERENCES, TRIGGER, MAINTAIN), but **no** SELECT/INSERT/UPDATE/DELETE. TRUNCATE is not subject to RLS, so it must be revoked in stage 7. If `supabase_admin` creates them, the inherited grants are broader. Run stage 3 with the confirmed migration role (U13) and record the grants each new table actually receives.

**Gate:** all existing rows unchanged (checksums identical to stage 2); new objects exist.
**Why before 4:** data can't be copied into columns or tables that don't exist.

## Stage 4 – Backfill and map existing data

- Copy remediation execution `108d5a0d…` into the chosen target (`playbook_runs` recommended), keeping the same UUID and status `succeeded → success`, with `legacy_source` set.
- Leave `approvals.playbook_run_id` NULL for `fdea11c4…` (not linkable).
- Leave `incidents.service_id` NULL unless the owner has decided otherwise in stage 1.
- `incident_logs` and `audit_log` have 0 rows, so there is nothing to copy.
- Record before/after counts per table.

**Gate:** every source record is accounted for (see checklist §D); no source row modified.
**Why before 5–6:** validation triggers added in stage 6 would reject legacy rows (e.g. a run without approval, a run against a disabled playbook).

## Stage 5 – Validate foreign keys and constraints

- Change delete behaviour to `RESTRICT` where approved (incident children, approvals, audit actor).
- Add new FKs (e.g. `approvals.playbook_run_id → playbook_runs`).
- Add new CHECK rules as `NOT VALID` first, then validate. If validation fails because of existing historical rows, apply the rule to new writes only and document the exception. Never "fix" history to pass a rule.
- Run orphan checks on every new FK.

**Gate:** all FKs valid; every constraint either validated or documented as new-rows-only.
**Why before 6:** triggers and functions assume these relationships exist.

## Stage 6 – Implement database functions and triggers

Designed in detail in checklist §W. Summary:
- `request_approval(run_id)`, `decide_approval(approval_id, decision, reason)`, `cancel_approval(approval_id)`: SECURITY DEFINER, `search_path = ''`.
- Approval immutability trigger (decided rows cannot change).
- Playbook-run guard trigger (playbook must be enabled; protected runs need an approved, linked approval before `running`).
- Recovery-check requirement before a run or incident can be marked fully resolved (rule wording to be confirmed in stage 1).
- Append-only audit trigger (block UPDATE/DELETE on `audit_logs`, including for the service role).
- Audit-writing function `log_audit_event(...)` that sets the actor and time itself.
- Update `handle_new_user()` for GitHub metadata.
- **Function permissions [V-LIVE, P3b]:** functions created by `postgres` get EXECUTE for `postgres` only (`{postgres=X/postgres}`), so client-facing functions need an explicit `authenticated` grant (never `anon`). Functions created by `supabase_admin` get EXECUTE for `anon`/`authenticated` by default, which would have to be revoked. Either way, set EXECUTE explicitly for every new function.
- **Existing-function baseline [V-LIVE, P3c, 2026-11-07]:** recorded in `SECURITY_AND_DATA_PRESERVATION_CHECKLIST.md` (P3c) and `PHASE19_FINAL_VERIFICATION_REPORT.md` (§8). Keep `admin_update_user_role`'s internal admin checks, and keep `is_admin`/`is_incident_manager` executable by `authenticated` (RLS depends on them). Only restrict client EXECUTE on the trigger-related functions (`handle_new_user`, `rls_auto_enable`, `set_updated_at`) after the rehearsal copy shows the triggers still work.
- **Post-migration:** re-run P3c and compare with this baseline. Any difference must be intended and documented.

**Gate:** unit tests per function/trigger pass on the rehearsal copy; legacy rows are still readable and unchanged.
**Why before 7:** RLS policies will call these functions and rely on their guarantees.

## Stage 7 – Implement RLS policies and grants

- Replace the risky policies listed in the report (S1–S5, S9).
- Add policies for the six tables that currently have none, per the role matrix.
- **Preserve** the verified current state (P3, 2026-11-07): `authenticated` has SELECT only on `profiles`, with no INSERT/UPDATE/DELETE. No migration step may grant UPDATE on `profiles` (in particular not on `role`). Role changes stay with `admin_update_user_role()`.
- Set explicit grants on the 3 new tables rather than relying on default privileges (checklist P3b). Revoke the inherited `TRUNCATE, REFERENCES, TRIGGER, MAINTAIN` from `anon`/`authenticated`, then grant only the SELECT/INSERT/UPDATE each role needs.
- Revoke direct INSERT/UPDATE on `approvals` and `audit_logs` for `authenticated`; writes go through functions.
- Revoke write access on the legacy tables.

**Gate:** policy review complete; every table has an explicit policy set or is documented as service-only.
**Why after 6:** policies reference the stage-6 functions.

## Stage 8 – Test authentication and authorization

- Email/password sign-up, sign-in and password reset.
- GitHub sign-in: new user, and a user whose email already exists (report S13).
- Profile creation via `on_auth_user_created`.
- One test identity per role (user, operator, admin) plus anonymous: run the full allow/deny matrix (checklist §R).
- Attempt self-role-escalation (must fail).

**Gate:** 100% of matrix cases behave as designed.
**Why before 9:** workflow tests depend on correct identities and roles.

## Stage 9 – Test approval and remediation workflows

Scenarios (all must behave as stated):
1. Requester cannot approve their own request.
2. A second eligible approver can decide; the decision cannot be changed afterwards.
3. A protected run cannot start without an approved, linked approval.
4. A run against a disabled playbook cannot be created or started.
5. A requester can cancel their own pending approval.
6. A successful remediation without a recovery check cannot be marked fully resolved.
7. Every step writes exactly one audit entry, which cannot be edited or deleted.
8. Legacy rows (`e48ca6e7…`, `fdea11c4…`, `108d5a0d…`) remain unchanged and readable.

**Gate:** all scenarios pass.

## Stage 10 – Test n8n integration

- n8n uses its own restricted credentials (not a user session). [DECISION NEEDED] A dedicated database role or a backend endpoint.
- Each workflow execution creates and updates exactly one `automation_runs` row, matched by `n8n_execution_id` (duplicate deliveries are ignored).
- n8n can never decide approvals.
- Failure and timeout paths set `failed`/`timed_out` and write audit entries.

**Gate:** end-to-end incident → investigation → approval → remediation → recovery → notification flow passes on staging.

## Stage 11 – Validate all records and counts

- Re-run the counts for all 18 original tables: identical to the stage 2 baseline (legacy tables included).
- Checksums of unchanged tables identical to baseline.
- The copied remediation record matches its source field by field.
- Re-run live Queries A–D on the rehearsal copy and record the expected differences (e.g. Query C still shows no approval row, by design).
- Complete the record-by-record checklist (checklist §D).

**Gate:** signed validation sheet. **Required before stage 13.**

## Stage 12 – Prepare rollback strategy

Designed alongside stage 2 and rehearsed before stage 13:
- **Level 1 (app):** revert the backend to the previous version. The schema is additive, so the old code keeps working until the new RLS is enabled.
- **Level 2 (policies):** saved copies of the previous policy definitions, so they can be re-applied in one script.
- **Level 3 (data):** restore from the stage-13 pre-migration backup into a new project or branch. [ASSUMPTION] Point-in-time recovery depends on the Supabase plan; confirm availability.
- Define rollback triggers in advance (e.g. auth failures, any count mismatch, any blocked legitimate workflow).
- Rehearse at least Level 2 and Level 3 on staging and time them.

**Dependency:** needs the proven backup from stage 2 and the final scripts from stages 3–7.

## Stage 13 – Plan production migration

- Owner approval of the stage 11 validation sheet and the stage 12 rollback rehearsal.
- Agree a maintenance window; pause n8n workflows; announce the freeze.
- Take a fresh production backup and hash it; verify counts against stage 2.
- Apply stages 3 → 7 in the same order as rehearsed. Gate checks between each.
- Smoke-test stages 8–10 (reduced set).
- Re-validate counts (stage 11).
- Resume n8n; monitor; keep the legacy tables read-only.
- Schedule legacy-table retirement as a **separate** future approval.

---

## Unresolved decisions (must be answered in stage 1)

| # | Decision |
|---|---|
| U1 | Where does remediation execution `108d5a0d…` go: `playbook_runs` (recommended) or `automation_runs`? |
| U2 | Approval link direction: `approvals.playbook_run_id` (recommended) or `playbook_runs.approval_id`, or both? |
| U3 | Deadlock fix: add a second admin (an owner decision; this plan does **not** change roles), let operators decide some approvals, and/or allow requesters to cancel. |
| U4 | What makes a playbook "protected": the `requires_approval` flag only, or also certain action types? |
| U5 | What happens to the enabled `Test Restart Playbook` that needs no approval. (This plan does not change it.) |
| U6 | Incidents with free-text `service_name`: create real service records, or leave them unlinked? |
| U7 | Test-data policy: keep, tag (e.g. `is_test`), or archive. |
| U8 | Audit `actor_id` FK: RESTRICT, or no FK. |
| U9 | n8n access method: dedicated role vs backend API. |
| U10 | GitHub sign-in with an existing email: link to the existing account or reject. |
| U11 | Exact recovery-verification rule (when is a check required, and who can override it). |
| U12 | Whether `incident_events` should be backfilled from audit history (recommended: no). |
| U13 | **Migration execution method and role – OPEN.** The method (Supabase SQL Editor or Supabase CLI) has not been formally selected yet.<br>• **SQL Editor context [V-LIVE, 2026-11-07]:** `current_user` = postgres, `session_user` = postgres, `current_role` = postgres, active role = none, `search_path` = `"$user", public, extensions`. Based on P3b, objects created this way inherit the verified `postgres` default ACLs.<br>• **Supabase CLI migration identity: pending.** Not verified; do not assume it is the same as the SQL Editor.<br>• Close U13 once the method is selected and its execution identity is verified. Changing live default privileges is a separate, later decision and not part of the audit stage. See checklist P3d. |

## Architecture decisions (stage 0 – blocking)

From the backend code security audit (report §9–§10, checklist §B). **Live database facts** (L-items), **backend code findings** (C-items), **inferences** (I-items) and **open verifications** (N-items) are kept separate in the report.

| # | Decision | Key evidence | Related |
|---|---|---|---|
| A1 | Canonical backend branch (`feature/backend-api` vs `origin/feature/backend-api-database`, or a merge). | C10, N2 | – |
| A2 | User-token/RLS architecture vs service-role/backend-only architecture. | C10, C11, I1–I4 | U13 |
| A3 | Canonical approval authority and authorized approver roles. | C2, C3 | U2, U3 |
| A4 | No-approval playbook execution rules. | C4 | U4, U5 |
| A5 | Secure n8n integration identity and webhook authentication. | C14, N1 | U9 |
| A6 | Notifications authentication and database compatibility. | C12, C13, N3 | – |
| A7 | Trusted audit logging (function-only writes; behaviour when an audit write fails). | L5, C8 | U8 |

> **⛔ NO MIGRATION SQL OR LIVE DATABASE CHANGES UNTIL THESE ARCHITECTURE DECISIONS ARE APPROVED.**
