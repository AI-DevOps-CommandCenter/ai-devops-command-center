# Security and Data Preservation Checklist

**Status:** Draft for review. Design only; no migration SQL.
**Labels:** [V-LIVE], [V-BACKUP], [V-SCHEMA] = verified · [ASSUMPTION] · [RECOMMENDATION] · [DECISION NEEDED]

Sections: **§S** safety rules · **§P** pre-migration read-only checks · **§D** record-by-record preservation · **§W** workflow and security design · **§R** roles and RLS · **§B** backend code findings and architecture decisions · **§V** final sign-off.

> ## ⛔ IMPLEMENTATION BLOCKER
> **NO MIGRATION SQL OR LIVE DATABASE CHANGES UNTIL THESE ARCHITECTURE DECISIONS ARE APPROVED** (§B5, decisions A1–A7).
> Status: **A1 APPROVED (2026-11-07)** · **A2–A7 PENDING**. The blocker remains until A2–A7 are approved.

---

## §S – Safety rules (apply to every stage)

- [ ] No INSERT/UPDATE/DELETE/DROP/ALTER/TRUNCATE on the live database outside the approved stage-13 window.
- [ ] All rehearsals run on a restored copy, never on live.
- [ ] No credentials, API keys or service-role keys in documents, commits, logs or screenshots.
- [ ] No user roles changed as part of the migration.
- [ ] No playbook enabled or disabled as part of the migration.
- [ ] No existing approval approved, rejected or cancelled as part of the migration.
- [ ] No missing data invented (timestamps, services, approvals, analyses, recovery checks).
- [ ] No existing record deleted, overwritten or silently skipped.
- [ ] Every finding labelled as verified fact, assumption or recommendation.

---

## §P – Pre-migration read-only checks (SELECT only)

These read the database without changing it.

- [ ] **P1. Row counts** for all 18 tables (live vs restored copy).
- [ ] **P2. Per-table checksums** (live vs restored copy). Example pattern, repeated per table:
  ```sql
  SELECT 'incidents' AS tbl, count(*) AS n,
         md5(string_agg(t::text, '|' ORDER BY t.id)) AS checksum
  FROM public.incidents t;
  ```
- [x] **P3. Who can update `profiles.role`** (resolves report S1). **Result 2026-11-07 [V-LIVE]:** `authenticated` has SELECT only on `public.profiles` (no INSERT/UPDATE/DELETE); the column-level UPDATE query returned no rows. Self-role-escalation is not possible. **Requirement:** keep direct client role updates disabled; role changes only via `admin_update_user_role()`. The full table-grant baseline for all tables is recorded below (P3 results).
  ```sql
  SELECT grantee, privilege_type, column_name
  FROM information_schema.column_privileges
  WHERE table_schema = 'public' AND table_name = 'profiles'
    AND privilege_type = 'UPDATE' AND grantee IN ('anon', 'authenticated');

  SELECT
      grantee,
      table_name,
      privilege_type
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public'
    AND grantee IN ('anon', 'authenticated')
  ORDER BY table_name, grantee, privilege_type;
  ```

  **P3 results – table-grant baseline, 2026-11-07 [V-LIVE]:**

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

  - **`anon`:** the query returned **no direct table grants** on any `public` table [V-LIVE].
  - **`authenticated` has no direct grant** on: `ai_analyses`, `audit_log`, `deployments`, `device_tokens`, `notifications`, `recovery_checks`, `services` (derived: these tables are absent from the result).

  **GRANT alone does not establish effective access.** A client can only act on a row when **both** of these allow it:
  - the GRANT (table/column privilege), **and**
  - an RLS policy for that operation (RLS is enabled on all 18 tables [V-SCHEMA]).

  So the effective access per table comes from combining this baseline with the policies in `public-schema.sql`. Examples [V-SCHEMA]:
  - `profiles` has an UPDATE policy but no UPDATE grant, so the policy has no effect.
  - `device_tokens` has own-row SELECT/INSERT/DELETE policies but no grant, so clients cannot register device tokens directly today (a functional review point).
  - `incidents` has no DELETE grant, so clients cannot trigger the incident delete cascades.

  **Security review points** (to resolve in stages 6–7; these are **not** confirmed vulnerabilities):

  | Table | Review point |
  |---|---|
  | approvals | Replace client INSERT/UPDATE with controlled approval functions (`request_approval`, `decide_approval`, `cancel_approval`); see §W1, §W5, §W6. |
  | audit_logs | Restrict direct client INSERT to a trusted audit-writing function (`log_audit_event`); see §W8. |
  | integrations | Keep management admin-only (current policy: admin ALL). Review whether client DELETE is needed at all, given history preservation. |
  | playbooks | Keep management admin-only (current policies: admin ALL + read enabled playbooks). Review client DELETE against history preservation (`playbook_runs` RESTRICT). |
  | playbook_runs | Clients must not directly control `status`, `approved_by`, `approved_at` or approval fields; changes go through the approval/run functions (§W3, §W4). |
  | remediation_executions | Preserve existing records (§D4). Review its migration into the canonical `playbook_runs` model (decision U1), then revoke client writes on the legacy table. |
  | incidents, investigations, postmortems, incident_logs | Keep the current grants under review against the §R1 matrix when the RLS policies are rewritten. |

  - Post-migration: re-run P3 (with `table_name`) and compare with this baseline. Any difference must be intended and documented.
- [x] **P3b. Default privileges for new tables.** **Result 2026-11-07 [V-LIVE]:** default ACL entries exist for objects created by both `supabase_admin` and `postgres`.
  - For `supabase_admin`: new tables get broad privileges for `anon`, `authenticated`, `service_role`; new sequences are accessible to `anon`/`authenticated`; new functions get EXECUTE for `anon`/`authenticated`.
  - For `postgres` (exact live values [V-LIVE]):

    | Object type | `defaclobjtype` | `defaclacl` |
    |---|---|---|
    | Tables | `r` | `{postgres=arwdDxtm/postgres,anon=Dxtm/postgres,authenticated=Dxtm/postgres,service_role=arwdDxtm/postgres}` |
    | Sequences | `S` | `{postgres=rwU/postgres}` |
    | Functions | `f` | `{postgres=X/postgres}` |

  - **What the ACL letters mean** (PostgreSQL 17): `a` INSERT · `r` SELECT · `w` UPDATE · `d` DELETE · `D` TRUNCATE · `x` REFERENCES · `t` TRIGGER · `m` MAINTAIN · `U` USAGE · `X` EXECUTE.
  - **So, for a new table created by `postgres`:**
    - `anon` and `authenticated` get `Dxtm`: **TRUNCATE, REFERENCES, TRIGGER and MAINTAIN**. They do **not** get SELECT, INSERT, UPDATE or DELETE.
    - `postgres` and `service_role` get all privileges (`arwdDxtm`).
  - **For a new sequence created by `postgres`:** only `postgres` gets access (SELECT, UPDATE, USAGE). `anon`/`authenticated` get none.
  - **For a new function created by `postgres`:** only `postgres` gets EXECUTE. Because this entry exists, the built-in "EXECUTE to PUBLIC" default does not apply. `anon`, `authenticated` and `service_role` cannot call it until EXECUTE is granted explicitly.
  - **What this means for the migration:**
    - **TRUNCATE is the main risk.** It is not subject to RLS, and it does not fire row-level DELETE triggers. An append-only design that relies on a row-level DELETE trigger would not stop it. Explicitly revoke `TRUNCATE` (and `TRIGGER`, `REFERENCES`, `MAINTAIN`) from `anon`/`authenticated` on every new table. For `audit_logs` and `approvals`, also add a statement-level guard against TRUNCATE (see §W6, §W8).
    - New tables get **no** read/write access for app users by default. Stage 7 must grant exactly the required SELECT/INSERT/UPDATE per table, matching the §R1 matrix.
    - New functions created by `postgres` are **not callable** by app users by default. Grant EXECUTE only on the client-facing functions (e.g. `request_approval`, `decide_approval`, `cancel_approval`), only to `authenticated` (and `service_role` where n8n/backend need them). Never grant to `anon`.
    - The defaults that apply depend on which role creates the objects (`postgres` vs `supabase_admin`). The SQL Editor runs as `postgres` [V-LIVE, P3d], so objects created there inherit the `postgres` defaults above. The CLI identity is still pending, so U13 stays open.
  - **Requirements:** do not rely on inherited defaults; set grants, RLS and function EXECUTE explicitly for every new object. Do not change live default privileges during the audit stage. Confirm the migration execution method and role (decision U13, P3d) before designing any default-privilege change.
  - Query used:
  ```sql
  SELECT pg_get_userbyid(d.defaclrole) AS owner, n.nspname AS schema,
         d.defaclobjtype AS object_type, d.defaclacl
  FROM pg_default_acl d
  LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
  WHERE n.nspname = 'public' OR d.defaclnamespace = 0;
  ```
- [x] **P3c. Who can execute the existing `public` functions.** P3b only covers objects created from now on, so the existing functions were checked separately. **Result 2026-11-07 [V-LIVE]:**

  | Function | anon | authenticated | SECURITY DEFINER |
  |---|---|---|---|
  | admin_update_user_role | false | true | true |
  | handle_new_user | true | true | true |
  | is_admin | false | true | true |
  | is_incident_manager | false | true | true |
  | rls_auto_enable | true | true | true |
  | set_updated_at | true | true | false |

  **How to read this:** `can_execute = true` only means the role is *allowed to call* the function. It is **not** a vulnerability by itself. What matters is what the function does and what it checks internally. No function is marked vulnerable on the basis of this result alone.

  **Requirements:**
  - **`admin_update_user_role`:** `anon` cannot execute it; `authenticated` can. It must **keep its internal checks**: the caller is authenticated, the caller is admin (`is_admin()`), no change to one's own role, and only allowed role values. These checks are what protect role changes, given that `authenticated` has no UPDATE on `profiles` (P3).
  - **`is_admin` / `is_incident_manager`:** must **remain executable by `authenticated`**, because the RLS policies call them to authorize users. Revoking EXECUTE would break RLS checks for logged-in users. `anon` correctly cannot execute them.
  - **`handle_new_user`, `rls_auto_enable`, `set_updated_at`:** these are trigger-related (a row trigger on `auth.users`, an event trigger, and `updated_at` row triggers). They are not meant to be called by clients, and PostgreSQL does not allow trigger functions to be called directly as normal functions. [RECOMMENDATION] Review and remove unnecessary client EXECUTE (`anon`/`authenticated`/`PUBLIC`) from these. **Test on the rehearsal copy first** that sign-up (`on_auth_user_created`), RLS auto-enable on new tables (`ensure_rls`) and `updated_at` triggers all still work afterwards. Trigger functionality must not break.
  - **New functions:** every new function gets **explicit** EXECUTE grants; nothing relies on defaults (see P3b).
  - **Post-migration:** re-run P3c and compare with this baseline. Any difference must be intended and documented.

  Query used:
  ```sql
  SELECT p.proname AS function_name, r.rolname AS role,
         has_function_privilege(r.oid, p.oid, 'EXECUTE') AS can_execute,
         p.prosecdef AS security_definer
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  CROSS JOIN pg_roles r
  WHERE n.nspname = 'public' AND r.rolname IN ('anon', 'authenticated')
  ORDER BY 1, 2;
  ```
- [ ] **P3d. Migration execution identity** (decision U13 – *open*).
  - [x] **SQL Editor context. Result 2026-11-07 [V-LIVE]:**

    | Setting | Value |
    |---|---|
    | current_user | postgres |
    | session_user | postgres |
    | current_role | postgres |
    | active role | none |
    | search_path | `"$user", public, extensions` |

    This verifies the **Supabase SQL Editor** execution context only. Based on P3b, objects created from the SQL Editor inherit the verified `postgres` default ACLs: tables give `anon`/`authenticated` `Dxtm` only; sequences and functions are `postgres`-only.
  - [ ] **Supabase CLI migration identity – pending.** Not verified. Do not assume CLI migrations run as the same role, or get the same default ACLs, as the SQL Editor. Verify this read-only before the CLI is chosen as the method.
  - [ ] **Execution method formally selected** (SQL Editor or Supabase CLI). U13 stays open until this is done and the chosen method's identity is verified.
  - Note: the SQL Editor `search_path` includes `public` and `extensions`. New SECURITY DEFINER functions should continue the existing pattern (`SET search_path = ''` with schema-qualified names), so they do not depend on the caller's path.
  - No default privileges are changed during the audit stage.
- [x] **P4. NULL check before tightening audit columns.** **Result 2026-11-07 [V-LIVE]:** `details` 0 NULLs, `created_at` 0 NULLs. NOT NULL is compatible with current data. **Requirement:** re-run P4 immediately before stage 5, because both columns still accept NULL and clients can insert audit rows until stage 7. Preserve all 24 records and verify them after migration (§D1).
  ```sql
  SELECT count(*) FILTER (WHERE details IS NULL)    AS null_details,
         count(*) FILTER (WHERE created_at IS NULL) AS null_created_at
  FROM public.audit_logs;
  ```
- [x] **P7. RLS policy inventory** (`pg_policies`, `public` schema). **Result 2026-11-07 [V-LIVE]:** the findings below (7a–7h) were confirmed by the project owner from the live `pg_policies` output.
  - **Source of the expression text:** transcribed from `public-schema.sql` [V-SCHEMA], because the raw live rows were not attached to this documentation.
  - [ ] **Open check:** paste or compare the raw live `pg_policies` rows against this table, to confirm the expression text matches character for character.

  Query:
  ```sql
  SELECT tablename, policyname, permissive, roles, cmd, qual AS using_expr, with_check
  FROM pg_policies
  WHERE schemaname = 'public'
  ORDER BY tablename, cmd, policyname;
  ```

  **How RLS combines:**
  - All policies are **permissive**, and all apply to role `authenticated`.
  - Multiple permissive policies for the same command combine with **OR**: a row is allowed if any one of them allows it.
  - An operation also needs the matching **GRANT** (P3). **Effective access = GRANT AND (policy 1 OR policy 2 …).**

  Notation: `uid()` = `( SELECT auth.uid() AS uid)`. `is_admin()` / `is_manager()` = `public.is_admin()` / `public.is_incident_manager()` (manager = admin or operator). `own_incident` = `EXISTS (SELECT 1 FROM incidents i WHERE i.id = <row>.incident_id AND (i.created_by = uid() OR is_manager()))`.

  | Table | Policy | Cmd | USING | WITH CHECK |
  |---|---|---|---|---|
  | approvals | Admins decide approval requests | UPDATE | `is_admin() AND requested_by <> uid() AND status = 'pending'` | `is_admin() AND requested_by <> uid() AND status IN ('approved','rejected') AND approver_id = uid()` |
  | approvals | Users create own approval requests | INSERT | – | `requested_by = uid()` |
  | approvals | Users view own approvals or admin | SELECT | `requested_by = uid() OR is_admin()` | – |
  | audit_logs | Admins view audit logs | SELECT | `is_admin()` | – |
  | audit_logs | Users insert own audit logs | INSERT | – | `actor_id = uid()` |
  | device_tokens | device_tokens_delete_own | DELETE | `user_id = auth.uid()` | – |
  | device_tokens | device_tokens_insert_own | INSERT | – | `user_id = auth.uid()` |
  | device_tokens | device_tokens_select_own | SELECT | `user_id = auth.uid()` | – |
  | incident_logs | Users create logs for own incidents or managers create all | INSERT | – | `own_incident` |
  | incident_logs | Users view own incident logs or managers view all | SELECT | `own_incident` | – |
  | incidents | Admins and operators update incidents | UPDATE | `is_manager()` | `is_manager()` |
  | incidents | Users create own incidents | INSERT | – | `created_by = uid()` |
  | incidents | Users view own incidents or managers view all | SELECT | `created_by = uid() OR is_manager()` | – |
  | integrations | Admins manage integrations | ALL | `is_admin()` | `is_admin()` |
  | investigations | Admins and operators update investigations | UPDATE | `is_manager()` | `is_manager()` |
  | investigations | Users create investigations for own incidents or managers creat | INSERT | – | `own_incident` |
  | investigations | Users view own investigations or managers view all | SELECT | `own_incident` | – |
  | playbook_runs | Admins and operators update playbook runs | UPDATE | `is_manager()` | `is_manager() AND (approved_by IS NULL OR approved_by <> requested_by)` |
  | playbook_runs | Users create own playbook requests or managers create all | INSERT | – | `requested_by = uid() AND own_incident` |
  | playbook_runs | Users view own playbook runs or managers view all | SELECT | `requested_by = uid() OR is_manager()` | – |
  | playbooks | Admins manage playbooks | ALL | `is_admin()` | `is_admin()` |
  | playbooks | playbooks_select_enabled | SELECT | `enabled = true` | – |
  | postmortems | Admins and operators create postmortems | INSERT | – | `is_manager()` |
  | postmortems | Admins and operators update postmortems | UPDATE | `is_manager()` | `is_manager()` |
  | postmortems | Users view own postmortems or managers view all | SELECT | `own_incident` | – |
  | profiles | View own profile or admin | SELECT | `id = uid() OR is_admin()` | – |
  | profiles | profiles_select_own | SELECT | `auth.uid() = id` | – |
  | profiles | profiles_update_own | UPDATE | `auth.uid() = id` | `auth.uid() = id` |
  | remediation_executions | Admins and operators create executions | INSERT | – | `is_manager()` |
  | remediation_executions | Admins and operators update executions | UPDATE | `is_manager()` | `is_manager()` |
  | remediation_executions | Users view own executions or managers view all | SELECT | `own_incident` | – |

  Total: 31 policies on 12 tables.
  - **No policies:** `ai_analyses`, `audit_log`, `deployments`, `notifications`, `recovery_checks`, `services`.
  - **DELETE coverage.** A policy with `cmd = ALL` also applies to DELETE.
    - `device_tokens`: authenticated users can DELETE their **own** rows (`device_tokens_delete_own`), subject to the matching GRANT. P3 shows no DELETE grant for `authenticated` on this table, so this policy currently has no effect.
    - `integrations`: only admins can DELETE rows (`Admins manage integrations`, `ALL`), subject to the matching GRANT. P3 shows a DELETE grant, so admin deletes are currently effective.
    - `playbooks`: only admins can DELETE rows (`Admins manage playbooks`, `ALL`), subject to the matching GRANT. P3 shows a DELETE grant, so admin deletes are currently effective. FK `playbook_runs → playbooks ON DELETE RESTRICT` still blocks deleting a referenced playbook [V-SCHEMA].
    - All other tables have **no** DELETE policy in the current inventory.
  - No policy applies to the `anon` role.

  **Findings.** "Confirmed" refers to the policy definition. Whether a risk can actually be exploited is stated separately and is **not** confirmed by this audit.

  - **7a. approvals [V-LIVE]**
    - Users can INSERT approval rows where `requested_by = auth.uid()` (INSERT grant exists, P3).
    - The INSERT policy does **not** itself enforce `status = 'pending'` or `approver_id IS NULL`.
    - **Risk (potential, not a confirmed exploit):** approval-state forgery, i.e. inserting a row that already appears approved or names an approver. Not yet checked: whether any trigger or backend path prevents this. The schema export shows no such trigger [V-SCHEMA]. Requires constraint/trigger/function review (§W1, §W6).
    - Note: the UPDATE policy only matches rows that are still `pending`, so clients already cannot UPDATE a decided row. Decided rows are not protected against service-role changes.
  - **7b. playbook_runs [V-LIVE] – high-priority workflow authorization risk**
    - Users can INSERT their own requests (`requested_by = auth.uid()`) for incidents they created. Managers can insert for any incident.
    - The INSERT policy does **not** constrain `status`, `approved_by` or `approved_at`.
    - Managers can UPDATE any row. The only approval-related check is `approved_by IS NULL OR approved_by <> requested_by`. The policy does **not** require a corresponding `approved` approvals record.
    - **Requires** database constraints/functions (§W3, §W4, §W5) **and a backend review** (the backend uses the service role, which bypasses RLS).
  - **7c. audit_logs [V-LIVE]**
    - Authenticated users can INSERT rows when `actor_id = auth.uid()`.
    - This lets users create audit entries under their own identity, with any action, entity and details.
    - **Audit-integrity risk.** Target design: trusted audit-writing function(s) only, and no direct client INSERT (§W8).
  - **7d. profiles [V-LIVE]**
    - `profiles_update_own` exists, but `authenticated` has no UPDATE grant (P3). Direct client updates are currently **blocked by the missing grant**.
    - Self-role-escalation is **not** a confirmed live vulnerability. It would only become one if an UPDATE grant were added. Keep the grant absent, and consider removing or narrowing the policy during stage 7 so it can't take effect by accident.
    - The two SELECT policies overlap (combined with OR).
  - **7e. device_tokens [V-LIVE] – functional integration gap**
    - Own-row SELECT/INSERT/DELETE policies exist, but `authenticated` has no direct table grant (P3), so the policies have no effect for clients.
    - Push-token registration must go through the backend or a function, or explicit grants must be added in stage 7.
  - **7f. integrations and playbooks [V-LIVE]**
    - Admin-only management (`ALL` with `is_admin()`) matches the target design.
    - Enabled playbooks are readable by all authenticated users (`playbooks_select_enabled`). Because policies combine with OR, admins see all playbooks and other users only enabled ones.
  - **7g. Tables without policies [V-LIVE]:** `ai_analyses`, `audit_log`, `deployments`, `notifications`, `recovery_checks`, `services`.
    - `authenticated` also has no direct grants on these tables (P3), so clients have no access.
    - **service_role access is not inferred from this audit.** It was not assessed here.
  - **7h. Ownership/manager checks vs the target matrix (§R1)**

    | Table | Current policy (live) | Target matrix | Gap / review point |
    |---|---|---|---|
    | incidents | INSERT own (`created_by = uid()`); SELECT own or manager; UPDATE manager; no DELETE (no grant or policy) | user: create own, read own; operator/admin: read all, update status | Matches for ownership. Review: user INSERT does not restrict status, severity, service or deployment fields; manager UPDATE has no column/transition limits. Soft delete (`archived_at`) is the target. |
    | incident_logs | INSERT/SELECT for own incident or manager; no UPDATE/DELETE | replaced by `incident_events` | Append-style already. Carry the same ownership model to `incident_events`; add actor binding. |
    | investigations | INSERT for own incident or manager; SELECT own incident or manager; UPDATE manager | user: read own; operator/admin: read/write all; n8n: write | **Difference:** users can currently create investigations for their own incidents; the target allows read-only for users. Decide in stage 1. |
    | postmortems | INSERT/UPDATE manager; SELECT own incident or manager | user: read own incidents; operator/admin: read/write | Matches. Review: `created_by` not bound to the caller (S9). |
    | remediation_executions | INSERT/UPDATE manager; SELECT own incident or manager | not in target (legacy → `playbook_runs`) | No approval check, `triggered_by` not bound. Preserve the existing record (§D4); revoke client writes after migration (U1). |
    | approvals | SELECT own or admin; INSERT own; UPDATE admin (not own, pending only) | decide: admin (not own), operator per U3 | Operators cannot read approvals today; must change if U3 lets operators decide. See 7a. |
- [ ] **P5.** Supabase dashboard: record the Auth provider settings (Email enabled; GitHub status), redirect URLs and any email-linking setting. Screenshots must not show secrets.
- [ ] **P6.** Confirm the Supabase plan's backup and point-in-time-recovery options. [ASSUMPTION] These are not yet known.

---

## §D – Record-by-record preservation

Each record: **keep the ID**, **no destructive change**, and verify after migration. Tick only after stage 11 validation.

### D1. audit_logs – 24 records [V-BACKUP]

- Actor for all 24: `2f826d1c…` (admin). Time range: 2026-11-03 17:13:49 → 2026-11-06 01:09:47 UTC.

| Action | Count | Entity |
|---|---|---|
| INCIDENT_CREATED | 2 | incidents `882078b5…`, `b32e62c7…` |
| INCIDENT_UPDATED | 1 | incident `b32e62c7…` |
| INTEGRATION_CREATED / UPDATED / DELETED | 1 / 1 / 1 | integration `2e748707…` (deleted) |
| PLAYBOOK_CREATED | 2 | `523dc40f…` (deleted), `27041cdf…` |
| PLAYBOOK_UPDATED / DELETED | 1 / 1 | `523dc40f…` |
| PLAYBOOK_RUN_REQUESTED | 1 | `e48ca6e7…` |
| POSTMORTEM_CREATED | 3 | `c570b488…`, `87ed9288…`, `291fca7b…` |
| POSTMORTEM_UPDATED | 6 | `291fca7b…` ×4, `87ed9288…` ×1, `c570b488…` ×1 |
| REMEDIATION_EXECUTION_CREATED / UPDATED | 1 / 2 | `108d5a0d…` |
| USER_ROLE_UPDATED | 1 | profile `5b41add3…` (to operator) |

- [ ] Count stays 24 (plus only new entries created by tests on the rehearsal copy).
- [ ] Checksum of the original 24 rows is unchanged.
- [ ] References to deleted entities (`2e748707…`, `523dc40f…`) are kept as-is.
- [ ] `entity_type = 'remediation_execution'` is kept as-is (not rewritten after the copy).
- [ ] Known gap documented, not filled: no audit entry for incident `6fc9b9e2…` creation, approvals or investigations.

### D2. Pending approval – `fdea11c4-a8af-4741-9b2e-5caa95b620d6`

- [ ] Still `pending`; approver_id NULL; decided_at NULL.
- [ ] `incident_id` = `6fc9b9e2…`; requested_by = `2f826d1c…`; requested_at unchanged.
- [ ] `playbook_run_id` (new) = NULL. Not linked to `e48ca6e7…` (different incident) or `108d5a0d…` (no evidence of a link).
- [ ] Owner decision on its future recorded separately (after the deadlock fix).

### D3. Pending playbook run – `e48ca6e7-81d6-4ab7-9c29-354b9d0127e7`

- [ ] Still `pending_approval`; approved_by NULL; payloads unchanged.
- [ ] playbook_id = `de8e209e…` (restart, still disabled); incident_id = `882078b5…`.
- [ ] Cannot move to `running` under the new rules while the playbook is disabled and no approval exists (verified by a stage 9 test, not by changing the record).

### D4. Successful remediation execution – `108d5a0d-078f-4834-9dcd-4ca6fe84919c`

- [ ] Original row still exists in `remediation_executions` (retained, read-only).
- [ ] Copy exists in the chosen target with the **same UUID**, status `success`, payloads identical, timestamps identical, `legacy_source` set.
- [ ] No approval or recovery check invented for it.
- [ ] Documented as "recovery unverified" in the report.

### D5. Investigations – 4 records

| ID | Incident | Status |
|---|---|---|
| `f6f96079-f3d3-4383-b537-206d9cbaac5d` | `6fc9b9e2…` | completed |
| `b60a7855-fa76-45b7-9f0a-789e7d74c15f` | `6fc9b9e2…` | completed |
| `7d5ca2b2-efc0-4d5a-afcd-1ded952ad694` | `6fc9b9e2…` | running |
| `157a8a06-c719-4855-a868-a6aab7f49014` | `b32e62c7…` | pending |

- [ ] All 4 kept with their statuses unchanged; none merged or removed as "duplicate".
- [ ] No ai_analyses rows generated from them.

### D6. Postmortems – 3 records

| ID | Incident |
|---|---|
| `c570b488-d4fa-4f70-8b39-864c364b34b0` | `882078b5…` |
| `87ed9288-76a2-4d2a-a817-1c2f95467d6e` | `6fc9b9e2…` |
| `291fca7b-7ca1-4bea-8402-5379be96c2bc` | `b32e62c7…` |

- [ ] All 3 kept; `timeline` and `action_items` JSON unchanged (not normalized).
- [ ] The new "postmortem after resolve" rule (if adopted) does not reject these existing rows.

### D7. Incidents – 3 records

| ID | Title | Status | service_name |
|---|---|---|---|
| `6fc9b9e2-d40a-43b9-afbc-26e8a9c4a386` | High CPU Usage | investigating | Payment Service |
| `882078b5-43ff-4d2c-9c89-4d87ea2a3a66` | RLS Security Test | open | Test Service |
| `b32e62c7-9df9-452d-9b4c-a7221b91e5c0` | Audit Logging Test | investigating | Test Service |

- [ ] All 3 kept; statuses unchanged; `service_name` text kept; `service_id` NULL unless decision U6 says otherwise.
- [ ] `acknowledged_at` left NULL (not invented).
- [ ] Child FKs changed to RESTRICT, so these incidents can no longer be deleted in a way that cascades.

### D8. Profiles and Auth – 2 records

| Profile ID | Role | Auth provider |
|---|---|---|
| `2f826d1c-8e0b-483c-9993-47a2d22ac62b` | admin | email |
| `5b41add3-c710-475a-9a11-fe9ee2dcb040` | operator | email |

- [ ] Both profiles still match their `auth.users` rows one-to-one.
- [ ] Roles unchanged.
- [ ] Both users can still sign in with email/password after migration.
- [ ] Email addresses are not copied into documents, logs or test fixtures.

### D9. Playbooks – 5 records

- [ ] All 5 kept (IDs in `MIGRATION_MAPPING.md` §2.8); `enabled` and `requires_approval` unchanged.
- [ ] `restart` (`de8e209e…`) and `Test Restart Playbook` (`27041cdf…`) both kept; they are not duplicates.
- [ ] `configuration` JSON unchanged.

### D10. Services – 2 records

| ID | Name | Environment | Status |
|---|---|---|---|
| `1c795cd4-6350-49fa-845d-8fb01fac00fb` | DevOps Command Center API | development | healthy |
| `48741d41-edba-4ce9-80b7-5019cfb9aaa4` | Authentication Service | development | healthy |

- [ ] Both kept unchanged.

---

## §W – Workflow and security design (Task D)

### W1. Requester / approver separation
- `CHECK (approver_id IS NULL OR approver_id <> requested_by)` on approvals. The existing row passes (its approver is NULL).
- Decisions only through `decide_approval()`, which sets `approver_id = auth.uid()` itself and refuses if the caller is the requester.
- Same rule for `playbook_runs.approved_by`: it can only be set by the approval flow, never directly.

### W2. Approval deadlock
- Root cause [V-LIVE]: only one admin exists, and only *other* admins may decide.
- Design options (**decision U3**; this migration does not change roles):
  - (a) The owner promotes or invites a second admin through the existing `admin_update_user_role()` flow, outside the migration.
  - (b) Allow operators to decide approvals for non-critical playbooks, still never their own.
  - (c) Let the requester **cancel** their own pending request (`cancelled` status).
  - (d) Optional `expires_at` with automatic `expired` status.
- Guard: when requesting, warn if no eligible approver exists, so new deadlocks are visible immediately.

### W3. Playbook disabled-state validation
- Trigger on playbook-run insert, and on the transition to `running`: the playbook must have `enabled = true`.
- Existing run `e48ca6e7…` is not rewritten; it simply cannot proceed.

### W4. Required approval before protected remediation
- A run is protected when its playbook `requires_approval = true` (plus action-type rules if decision U4 adds them).
- A protected run may move to `approved`/`running` only if a linked approval with status `approved` exists.
- `approval_required` on the run is copied from the playbook when the run is created, so later playbook edits can't weaken an existing request.

### W5. Linking approvals to playbook_runs
- `approvals.playbook_run_id` FK, `ON DELETE RESTRICT`.
- At most one **pending** approval per run (partial unique rule).
- `request_approval(run_id)` creates the approval with incident and requester taken from the run, so they can't be mismatched.
- Incident-level approvals (`playbook_run_id` NULL) remain valid for history, e.g. `fdea11c4…`.

### W6. Immutable approval decisions
- Trigger: once the status is `approved`, `rejected`, `cancelled` or `expired`, any UPDATE or DELETE is refused, including via the service role.
- INSERT must have `status = 'pending'` and `approver_id IS NULL`. This closes the self-approval-at-insert gap (report S2).
- Every decision writes an audit entry in the same transaction.
- TRUNCATE on `approvals` is revoked from client roles and blocked by a statement-level guard (see P3b).

### W7. Recovery verification after remediation
- After a run reaches `success`, a `recovery_checks` row linked to that run is expected (created by n8n or by an operator).
- An incident cannot move to `resolved` while it has a successful protected run without a `healthy` recovery check (exact rule and override: **decision U11**; an override is audited).
- Historical execution `108d5a0d…` is exempt from the rule but listed as unverified.

### W8. Append-only audit history
- A trigger blocks UPDATE and DELETE on `audit_logs` for everyone, including the service role.
- TRUNCATE is blocked separately: revoke TRUNCATE from `anon`/`authenticated`, and add a `BEFORE TRUNCATE` statement-level guard. Row-level triggers do not fire on TRUNCATE (see P3b).
- Revoke direct INSERT for `authenticated`. Writes go through `log_audit_event()`, which sets `actor_id = auth.uid()` and `created_at = now()` (closes report S5).
- Resolve the `actor_id ON DELETE SET NULL` conflict (decision U8).
- `audit_log` (legacy) has its write access revoked.

### W9. Service / incident relationship validation
- New incidents must reference an existing service (`service_id` NOT NULL for new rows, via trigger or `NOT VALID` check). Existing NULLs are kept.
- If a deployment is given, it must belong to the same service.
- `service_name` is kept for history only; new code reads the name from `services`.

### W10. Preserve history on delete
- Child FKs to incidents and playbook_runs become RESTRICT.
- Incidents use `archived_at` (soft delete) instead of hard delete.

---

## §R – Role-based permissions and RLS

### R1. Permission matrix (proposed)

| Capability | user | operator | admin | n8n / service |
|---|---|---|---|---|
| Read own profile | ✓ | ✓ | ✓ | – |
| Read all profiles | – | – | ✓ | – |
| Change any role | – | – | ✓ (not own; via function) | – |
| Change own role | ✗ | ✗ | ✗ | ✗ |
| Read services / deployments | ✓ | ✓ | ✓ | ✓ |
| Manage services | – | ✓ | ✓ | ✓ (status only) |
| Create incident | ✓ (own) | ✓ | ✓ | ✓ |
| Read incidents | own | all | all | all |
| Update incident status | – | ✓ | ✓ | ✓ (limited) |
| Investigations / AI analyses | read own | read/write all | read/write all | write |
| Manage playbooks / enable/disable | – | – | ✓ | – |
| Request playbook run | own incidents | ✓ | ✓ | ✓ |
| Decide approval | – | per decision U3 | ✓ (not own) | ✗ never |
| Cancel own pending approval | ✓ | ✓ | ✓ | – |
| Execute approved run | – | ✓ | ✓ | ✓ |
| Recovery checks | read own | read/write | read/write | write |
| Notifications inbox | own | own | own | write |
| Notification deliveries | – | – | read | write |
| Device tokens | own | own | own | read (for sending) |
| Integrations | – | – | ✓ | read config ref |
| Audit logs | – | – | read | append via function |
| Postmortems | read own incidents | read/write | read/write | draft |
| automation_runs | – | read | read | write |

### R2. RLS checklist
- [ ] Every table has explicit policies for each operation it allows. Nothing relies on "no policy = denied" except the documented service-only tables.
- [ ] Policy changes are designed against the live baseline (P7) **and** the grant baseline (P3) together, because effective access needs both. Remember that permissive policies for the same command combine with OR: adding a policy can only widen access.
- [ ] Post-migration: re-run P7 and compare with this baseline. Any difference must be intended and documented.
- [ ] Policies call `(SELECT public.is_admin())` and `(SELECT public.is_incident_manager())` in the cached form.
- [ ] `profiles`: duplicate SELECT policies merged. `authenticated` keeps **no** INSERT/UPDATE/DELETE grant (verified current state, P3). If self-service name editing is ever wanted, grant UPDATE on specific columns only (e.g. `full_name`) – never on `role`.
- [ ] Post-migration: re-run P3 and confirm the result is unchanged.
- [ ] New tables: explicit grants set deliberately, not left to default privileges (P3b showed defaults are broad).
- [ ] New SECURITY DEFINER functions (`decide_approval`, `request_approval`, `cancel_approval`, `log_audit_event`, …): EXECUTE explicitly revoked from `PUBLIC` and `anon`, granted only to the roles that need it. Each function also checks `auth.uid()` and the caller's role internally.
- [ ] Trigger-only functions (immutability, guards, append-only audit) are not callable as API functions by clients.
- [ ] After migration, re-run P3, P3b and P3c and compare with the pre-migration baseline.
- [ ] `approvals`: no direct INSERT/UPDATE for clients; functions only.
- [ ] `playbook_runs`: clients cannot set `status`, `approved_by` or `approved_at` directly.
- [ ] `audit_logs`: SELECT admin-only; no client UPDATE/DELETE; INSERT via function.
- [ ] `notifications` / `device_tokens`: owner-only.
- [ ] `integrations`: admin-only; secrets kept outside plain JSON (Vault).
- [ ] New tables (`incident_events`, `notification_deliveries`, `automation_runs`) have policies before any client uses them.
- [ ] Legacy tables: no client access; writes revoked.
- [ ] Backend service-role usage reviewed: every backend route enforces the same role checks (report S8). *Under approved A1, user-facing routes use the publishable key + user JWT. Any remaining privileged server-side operation must use the controlled mechanism defined under A2 (pending).*
- [ ] `anon` has no access to any `public` table except what is explicitly required.

### R3. Authentication checklist
- [ ] Email/password sign-up, sign-in and reset work.
- [ ] GitHub provider configured; callback URLs correct; client secret stored only in Supabase.
- [ ] `handle_new_user()` handles GitHub metadata and the duplicate-email case (decision U10).
- [ ] New users always start as `user`.

---

## §B – Backend code findings and architecture decisions (2026-11-07)

Full evidence, with file paths and line numbers, is in `PHASE19_FINAL_VERIFICATION_REPORT.md` §9–§10. The four categories are kept separate here. **Untested direct-API behaviour is an inference, not an executed exploit.**

### B1. Verified live database findings [V-LIVE]
- [x] No user-created triggers on `approvals`, `playbook_runs`, `remediation_executions`, `audit_logs` (L1).
- [x] No constraint enforces pending-only approval insert, `approver_id <> requested_by`, an approval record before an approved run, remediation linked to an approval decision, or audit immutability (L2).
- [x] Client grants and policies allow direct INSERT/UPDATE on `approvals` and `playbook_runs`, and INSERT on `audit_logs` (L3–L5; P3, P7).

### B2. Verified backend code findings [V-CODE]
- [x] Backend approval creation is pending-only (C1). The approval decision is admin-only, with self-separation relying on RLS (C2).
- [x] `approvals` and `playbook_runs` use **different approval authorization rules** (admin only vs admin or operator), and the two are not linked (C3).
- [x] `requires_approval = false` playbooks auto-approve runs (C4). The enabled check exists only in the backend (C5).
- [x] Remediation execution **does not verify an authoritative approval record**, and accepts arbitrary status and timestamps on update (C6).
- [x] Audit logging is **best-effort and can silently fail**. Users can create entries (C8 + L5).
- [x] Notifications service uses **service_role without route authentication**, and takes `userId` from the request body (C12).
- [x] Notifications service **column/table names do not match the live schema** (C13).
- [x] The current backend branch (service_role) and `backend-api-database` (user token + RLS) use **different Supabase access architectures** (C10).
- [x] No n8n webhook code or workflow exists in the repository (C14).

### B3. Inferences (not executed)
- Direct approval insertion can bypass the pending-only workflow (I1).
- Direct playbook-run insertion can create already-approved runs (I2).
- A manager-requester could set `approved_by` to another user directly (I3).
- Backend-only rules offer no independent protection where clients can reach the database (I4).

### B4. Needs further verification
- [ ] n8n workflow authentication and credentials in the running instance (N1).
- [ ] Deployed or canonical backend branch (N2).
- [ ] Notifications service deployment and exposure (N3).
- [ ] I1–I3 confirmed by test on the **rehearsal copy only** (N4).
- [ ] Other direct Supabase clients (N5).

### B5. Architecture decisions – must be approved before any SQL
- [x] **A1** Canonical backend branch – **APPROVED 2026-11-07.** Hybrid architecture: base `origin/feature/backend-api-database`; user-token + RLS as the primary database security model; port the auth/profile middleware, role middleware, zod, helmet, Vitest/Supertest and password reset (after redirect review) from `feature/backend-api`. Rejected alternative: service_role/backend-only. Full record: report §11. **Not implemented yet.**
- [ ] **A2** User-token/RLS architecture vs service-role/backend-only architecture – **PENDING.** A1 sets user-token + RLS as primary. Still open: the controlled mechanism for privileged server-side operations, and the final grant/RLS boundary.
- [ ] **A3** Canonical approval authority and authorized approver roles – **PENDING.**
- [ ] **A4** No-approval playbook execution rules – **PENDING.**
- [ ] **A5** Secure n8n integration identity – **PENDING** (A1 principle: dedicated limited identity, authenticated machine-to-machine requests, no service_role).
- [ ] **A6** Notifications authentication and database compatibility – **PENDING** (A1 principle: dedicated limited identity, no service_role).
- [ ] **A7** Trusted audit logging – **PENDING.**

**A1 security requirements (approved principles, to verify during implementation):**
- [ ] The service_role key is never present in the Flutter app, n8n or the notifications service.
- [ ] Every user-facing database call uses the publishable key with the caller's JWT.
- [ ] Every privileged server-side operation goes through an explicitly authorized, controlled mechanism (defined under A2).
- [ ] Approval, remediation and audit rules are enforced by database constraints, RLS or trusted functions, not only by backend or frontend code.
- [ ] Backend role checks remain as an additional layer.
- [ ] Machine-to-machine requests (n8n, notifications) are authenticated.

**⛔ NO MIGRATION SQL OR LIVE DATABASE CHANGES UNTIL A2–A7 ARE ALSO APPROVED.**

---

## §V – Final sign-off

- [x] Architecture decision A1 approved and recorded (2026-11-07; report §11).
- [ ] Architecture decisions A2–A7 approved (§B5) and recorded.

- [ ] All §P checks recorded.
- [ ] All §D records ticked on the rehearsal copy.
- [ ] All §W designs implemented and tested on the rehearsal copy (stage 9).
- [ ] §R matrix tested with one identity per role (stage 8).
- [ ] Rollback rehearsed and timed (stage 12).
- [ ] Owner approval recorded before production (stage 13).
