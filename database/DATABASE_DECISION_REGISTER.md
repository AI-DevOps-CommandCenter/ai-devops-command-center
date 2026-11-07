# Database Decision Register

**Project:** AI-Powered Mobile DevOps Command Center
**Branch:** `feature/database-implementation`
**Created:** 2026-11-07 (Phase 2, Decision Batch 1)
**Companion document:** `database/COMPLETE_DATABASE_IMPLEMENTATION_ROADMAP.md`

This register records architecture and implementation decisions for the database work. It **does not replace** the committed Phase 19 register (`MIGRATION_EXECUTION_PLAN.md` "Architecture decisions", on `feature/backend-api`). It references that register and adds decisions taken since.

> ## Implementation blocker: LIFTED for local work (Batch 2, 2026-11-07)
> A2–A7 were approved in Decision Batch 2 (§2c) and implemented and tested **locally** (§2d).
> **Still blocked:** any remote database change. Remote apply needs D-009 (staging credentials and access), the backend switch (handover §1a) and, for production, the explicit written approval in handover §6.

### Status values

| Status | Meaning |
|---|---|
| **APPROVED** | Decided by the project team and recorded here. |
| **PARTIALLY ANSWERED** | Some sub-questions answered; the decision as a whole is still open. |
| **PENDING** | In the committed register; not decided. |
| **PROPOSED** | Suggested in the A2–A7 report; not in the committed register; not decided. |
| **OPEN** | A question with no answer yet. |

**Approver field.** Batch 1 was recorded on the project team's instruction in a working session on 2026-11-07. No approver name was given, so the named sign-off is left for the approver to complete. Nothing here invents an approver.

---

## 1. Register overview

| # | Decision | Status | Where recorded |
|---|---|---|---|
| A1 | Canonical backend branch (hybrid; user JWT + RLS primary) | **APPROVED** 2026-11-07 | Committed Phase 19 docs (`56c6b82`) |
| A2 | User-token/RLS vs service-role; privileged mechanism; final grant/RLS boundary | **APPROVED** Batch 2 (2026-11-07). Implemented locally (000400–000700). | §2c |
| A3 | Approval authority and approver roles | **APPROVED** Batch 2, with A3-Q1, A3-Q3 and A3-Q4 answered. Implemented locally (000700). | §2c |
| A4 | No-approval playbook rules | **APPROVED** Batch 2. Implemented locally (000700). | §2c |
| A5 | n8n identity and webhook authentication | **APPROVED** Batch 2. Implemented locally (000400 + backend `machine-auth.ts`). A5-Q2 open. | §2c |
| A6 | Notifications authentication and database compatibility | **APPROVED** Batch 2. Implemented locally (000600). | §2c |
| A7 | Trusted audit logging | **APPROVED** Batch 2, with A7-Q3 answered. Implemented locally (000500). | §2c |
| A8 | Existing database reconciliation | **PROPOSED** (Q-X1 open) | A2–A7 report §6 |
| A9 | Actor model | **PROPOSED** (Q-X1 open) | A2–A7 report §4 |
| A10 | Migration and deployment strategy | **PROPOSED** (Q-X1 open). Two of its questions are answered by D-004/D-005 as standalone decisions. | A2–A7 report §7 |
| D-001 | No general runtime service_role (A2-Q1) | **APPROVED** Batch 1 | §2 |
| D-002 | Middleware uses the user JWT and a per-request client (R7 / A2-Q6) | **APPROVED** Batch 1 | §2 |
| D-003 | Bring the Phase 19 documentation onto this branch (R1) | **APPROVED** Batch 1. **Performed** 2026-11-07: commits `41b6772`, `bb11fdb`, `55c9a1b` (§5.5). | §2 |
| D-004 | Supabase CLI with `supabase/migrations/` (R2; method part of U13; A10-Q2) | **APPROVED** Batch 1 | §2 |
| D-005 | Separate staging Supabase project for rehearsal and testing (R12; A10-Q1 in part) | **APPROVED** Batch 1 | §2 |
| D-006 | Include the A2–A7 report in the D-003 copy (B1-1) | **APPROVED** Batch 1b. Performed (`55c9a1b`). | §2a |
| D-007 | Synthetic test data only in staging (B1-2) | **APPROVED** Batch 1b | §2a |
| D-008 | Historical SQL preserved unchanged as reference only (B1-3) | **APPROVED** Batch 1b | §2a |
| D-009 | Confirm staging ownership and credential management before connecting the CLI (B1-4) | **APPROVED** Batch 1b. **Ownership decided** 2026-11-07 (team leader; proposed project details). Credential storage and individual access **pending**. Project **not created**. | §2a |

### 1.1 Definitions of A8, A9 and A10 (quoted from `A2_A7_ARCHITECTURE_DECISION_REPORT.md`, commit `030df62`)

All three are labelled in the report as **"PROPOSED NEW DECISION — NOT IN THE COMMITTED REGISTER — NOT APPROVED"**. Accepting them into the register is question **Q-X1**: *"Accept A8 (database reconciliation), A9 (actor model) and A10 (migration & deployment) as new decisions in the Phase 19 register, and approve any additional implementation gates they introduce?"*

| # | Topic, as mapped in report §0.2 | Recommendation summary (report §1) | Purpose (report "Why") |
|---|---|---|---|
| **A8** | "Existing database reconciliation … (no committed number covers it)". Section header: *"A8 – Existing Database Reconciliation … Builds on `MIGRATION_MAPPING.md` and the open items U1, U6, U7, U8."* | "Additive reconciliation to the 18-table target. Keep all 46 existing rows with their IDs. Retire 3 legacy tables only after sign-off. Make one versioned schema the source of truth." | "Lowest risk of data loss, every stage reversible, and it creates the missing source of truth needed by A10." |
| **A9** | "Identity & automation actors – general actor model (user/operator/admin/system/AI attribution) … (A5/A6 cover only the two machine identities)". Section note: *"the general identity and actor-attribution model (user, operator, admin, system, AI) that A5 and A6 rely on."* | "Actor types `user` / `operator` / `admin` / `automation` (n8n) / `system` (database) / `ai` (attribution label only). Every record carries `actor_type` + `actor_id`. No actor can raise its own role or decide approvals unless it is a human." | "Keeps A1's JWT + RLS model for machines too, makes every action attributable, and keeps humans as the only approvers." |
| **A10** | "Migration & deployment strategy … (builds on the plan's stages 0–13 and U13)". Section header: *"Builds on `MIGRATION_EXECUTION_PLAN.md` stages 0–13 and open item U13 (migration execution method)."* | "A versioned migration repository. Rehearsal on a separate non-production environment from a proven restore. Fixed execution identity. Additive-first stages with gates, pre/post validation, a timed rollback and owner sign-off." | "Turns a single, unversioned live database into a reproducible, reviewable system with a proven way back." |

The report also says: *"If A8–A10 are not accepted into the register (Q-X1), their content remains as supporting analysis for A2–A7 and the existing migration plan."* **Q-X1 is still OPEN.** Batch 1 doesn't accept A8–A10. D-004 and D-005 are recorded as standalone decisions. If A10 is accepted later, they become its answers to A10-Q2 and A10-Q1.

---

## 2. Decision Batch 1 (2026-11-07)

### D-001 – No general runtime service_role (answers A2-Q1)
- **Decision (as instructed):** "No general runtime service_role usage. Allow only isolated, explicitly authorized Auth-admin operations if genuinely required, with strict auditing."
- **Status:** APPROVED, Batch 1. **A2 as a whole stays PENDING**: A2-Q2, A2-Q3, A2-Q4 and A2-Q5 are open.
- **Scope and consequences:**
  - **Out of the request path:** no service_role in the backend request path, Flutter, n8n or the notifications service.
  - **Exception rules:** any exception must be:
    1. a specific Supabase Auth admin operation that cannot be done with the user JWT or a narrow database function;
    2. explicitly authorized, case by case, in this register before implementation;
    3. kept in an isolated server module outside normal request handling;
    4. audited on every use (who, what, when).
  - **No exception exists today.** No current requirement for one has been found. The existing role change uses the `admin_update_user_role` function with the user JWT (`backend/src/services/admin.service.ts:44`). The password reset in the A1 port source uses the public client (`feature/backend-api:backend/src/routes/auth.routes.ts:44`).
- **Consistency:**
  - **A1:** consistent. A1 forbids service_role in Flutter and n8n and makes user JWT + RLS primary; D-001 is stricter, which A1 allows.
  - **A6:** consistent with the report's A6 recommendation. The last known notifications code used service_role and must not.
  - **U-items:** no conflict.
- **Follow-up:** each future exception gets its own register entry (D-0xx), with operation, storage location, reviewer and audit method.

### D-002 – Authentication middleware uses the user JWT (answers R7 / review question A2-Q6)
- **Decision (as instructed):** "Rewrite the authentication middleware to use the user's JWT and a per-request Supabase client. Never use service_role for normal request authentication or profile/role checks."
- **Status:** APPROVED, Batch 1.
- **Scope and consequences:**
  - When A1's port is done, the `requireAuth`/`requireRole` logic from `feature/backend-api` is rewritten, not copied. That source uses a service_role client: `feature/backend-api:backend/src/middleware/auth.ts:2,28,39` and `lib/supabase.ts:7,15-17`.
  - Token verification stays with `supabase.auth.getUser(token)` using the publishable key. The per-request client (`backend/src/config/supabase.ts` `createUserSupabaseClient`) is used for profile and role reads under RLS.
  - Profile reads rely on the existing `profiles` SELECT policies [V schema export].
- **Consistency:**
  - **A1:** consistent; this is how A1's "user JWT + RLS primary" applies to the ported middleware.
  - **D-001:** consistent. No conflict with any U-item.
- **Implementation:** roadmap Phase 6. This is application code, so it isn't changed in this phase.

### D-003 – Bring the Phase 19 database documentation onto this branch (answers R1)
- **Decision (as instructed):** "Bring the Phase 19 database documentation onto the current `feature/database-implementation` branch. Preserve the original documents without silently changing their contents. Inspect the source branch and report any conflicts before copying."
- **Status:** APPROVED, Batch 1. **Performed 2026-11-07** (§5.5). The pre-copy inspection is in §5.
- **Scope:**
  - The four Phase 19 documents.
  - The A2–A7 report, which is a follow-up on the same branch. Whether it counts as "Phase 19 documentation" needs confirmation: **open item B1-1**.
  - Historical SQL (`schema.sql`, `001`) is **not** part of D-003. Its status is recorded under D-004 (§6).
- **Consistency:** no conflict with A1 or any U-item. A wording issue in the copied documents is recorded in §5.3. It is handled by a note, not by editing the originals.

### D-004 – Supabase CLI with `supabase/migrations/` (answers R2; selects the method in U13; answers A10-Q2 as a standalone decision)
- **Decision (as instructed):** "Use Supabase CLI with version-controlled migrations under `supabase/migrations/`. Preserve existing historical SQL files and document their status. Do not treat an old migration as a production-ready baseline without verification."
- **Status:** APPROVED, Batch 1.
- **Consequences:**
  - **File layout:** migrations live in `supabase/migrations/` in the CLI's naming format (timestamp prefix). Roadmap references to `000_baseline` and `002_…` become `<timestamp>_baseline.sql` and so on, in that folder.
  - **Historical SQL:** existing files stay where they are, unchanged (§6). `001_align_with_proposal.sql` is **not** copied into `supabase/migrations/` and is **not** treated as a baseline.
  - **Baseline source:** the baseline must be captured from the live schema and verified on staging (D-005) before it is trusted.
  - **Production history table [A]:** a database whose schema existed before the CLI has no CLI migration history. Marking the baseline as already applied on production writes to that database. It needs its **own approval** at production time, and nothing is done now.
- **Effect on U13:**
  - The **method** part is now decided: Supabase CLI.
  - **U13 stays OPEN** for the **execution identity**. The committed plan says: *"Supabase CLI migration identity: pending. Not verified; do not assume it is the same as the SQL Editor. Close U13 once the method is selected and its execution identity is verified."* The identity must be verified (read-only) first on staging, then on production before Phase 15.
- **Consistency:**
  - **A1:** consistent.
  - **U13:** consistent; it narrows U13 and does not contradict it.
  - **Report's A10 recommendation:** consistent ("Versioned migrations (Supabase CLI or equivalent)").
  - **A8-Q4** (baseline from live): consistent; D-004 adds the verification requirement.
- **Prerequisites:** see §4. The Supabase CLI is **not installed** on the current workstation [V: `supabase` command not found].

### D-005 – Separate staging Supabase project (answers R12; answers A10-Q1 in part)
- **Decision (as instructed):** "Use a separate staging Supabase project for migration rehearsal and testing. Do not use production as the rehearsal environment."
- **Status:** APPROVED, Batch 1. **Not yet provisioned.** Availability, plan and cost are **[UNKNOWN]** (A10-Q1 part 2 open).
- **Consequences:**
  - Roadmap phases 4–14 run on staging only; Phase 15 is the only production phase.
  - Staging gets its own keys, secrets and configuration, never shared with production.
- **Consistency:**
  - **Committed plan:** consistent with its principle *"Never rehearse on live. Stages 3–11 run first on a restored copy (local Postgres 17 or a separate Supabase staging project/branch)."* D-005 selects the staging-project option. A local copy can still be used for developer testing, but rehearsal and the gates use staging.
  - **A1:** consistent. No conflict with any U-item.
- **Requirements:** see §4.

---

## 2a. Decision Batch 1b (2026-11-07)

Approved by the project team in the working session on 2026-11-07. The named sign-off is left for the approver to complete.

### D-006 – Include the A2–A7 report (answers B1-1)
- **Decision:** "Include the A2–A7 architecture decision report in the current `feature/database-implementation` branch."
- **Done:** copied unchanged as part of D-003 (commit `55c9a1b`, cherry-picked from `030df62`).

### D-007 – Synthetic test data in staging (answers B1-2)
- **Decision:** "Use synthetic test data in the staging environment. Do not copy real production user data or credentials."
- **Consequences:**
  - The existing full-database backup (which contains `auth`, `public`, `storage`, `realtime` and `vault`) is **not** restored into staging. Staging gets the schema only.
  - Test users are created in staging Auth, and their `profiles` rows satisfy `profiles.id → auth.users`.
  - Synthetic records must reproduce the **shapes** that matter for the migration tests: pending approval with requester = only admin, pending run, legacy remediation row, 24-style audit history, free-text `service_name`. They must not contain production values (emails, names, IDs).
  - **Preservation is verified differently.** Proof that the **46 production records** survive comes from read-only counts and checksums before and after the production migration (Phase 15, checklist P1/P2/§D), not from staging.
- **Constraint:** synthetic data exists only in staging. It is never added to production (mapping rule "No invented data").
- **Consistency:** consistent with A1, D-005 and the mapping rules. It replaces the restore-based rehearsal wording in the committed plan (stage 2 "test restore") **for staging**. Whether a restore test of the production backup is still required somewhere safe (e.g. a local, access-controlled database) is **open: B1b-1**.

### D-008 – Historical SQL kept as reference only (answers B1-3)
- **Decision:** "Preserve `schema.sql` and `001_align_with_proposal.sql` as historical reference files, unchanged. Do not execute them or treat them as the current baseline."
- **Status:** both stay unchanged on `origin/feature/database` (§6). They were **not** copied in Phase 3 step 1. Copying them onto this branch as read-only references is a later, separate step, if wanted.

### D-009 – Ownership and credentials before CLI connection (answers B1-4)
- **Decision:** "Staging project ownership and credential management must be confirmed with the team/project owner before connecting the CLI."
- **Gate:** `supabase link` (or any CLI connection to staging) must not happen until these are confirmed and recorded here:
  1. the staging project owner;
  2. who holds the CLI access token and the staging database password;
  3. where they are stored (A2-Q4).
- **Status:** item 1 decided (below). Items 2 and 3 are **pending**, so the gate is **still closed**: no CLI connection yet.

#### D-009 ownership decision (2026-11-07)
This is the team leader's approved ownership decision with **proposed** project details. **The staging project does not exist yet.** Nothing has been created, linked or connected.

| Item | Decision | Status |
|---|---|---|
| Staging project owner | The current project team leader | **APPROVED** |
| Supabase organization | `AI-DevOps-CommandCenter` | **APPROVED** (organization access not verified in this repository) |
| Project name | `devops-command-center-staging` | **PROPOSED** |
| Region | `ap-southeast-1` (Singapore) | **PROPOSED** |
| Access | Only authorized team members, each with the minimum required access | **APPROVED** principle; individual assignments **PENDING** |
| Data | Synthetic test data only (same as D-007) | **APPROVED** |
| Production data | Never copy production user data or credentials into staging | **APPROVED** |
| Credential storage (CLI access token, staging database password, staging API keys) | Not yet decided (A2-Q4) | **PENDING** |
| Individual access assignments | Not yet decided | **PENDING** |

Notes:
- The production project's region is not recorded in this repository **[UNKNOWN]**. Whether staging should match it is not part of this decision.
- The team leader is recorded by role only; no name was given.

---

## 2b. Implementation record (2026-11-07)

**Instruction recorded:** the project lead's session instruction of 2026-11-07 asked for the baseline and additive migrations to be prepared and tested. They were prepared and tested **locally only**: a throwaway PostgreSQL cluster on 127.0.0.1, with synthetic data. **Nothing was applied to staging or production.**

- **What the blocker still covers:** it continues to apply to every **remote** database. Migrations 000100–000300 contain **no** decision-dependent logic (§7).
- **Confirmation needed:** the team leader to confirm this reading of the blocker (open item **B2-1**).

| Commit | Content |
|---|---|
| `d798f43` | P1 backend groundwork (D-001/D-002) |
| `1bca4f2` | Baseline migration (verified), synthetic seed (D-007), local test harness and 7 suites |
| `e2e51da` | Additive: FK indexes, `automation_runs` / `incident_events` / `notification_deliveries` (no client access), nullable link columns, guarded rollbacks, suite 08 |

**Verification sources for the baseline:**
- **Structure:** the structure export, cross-checked against the backup archive's object list (definitions only, no table data read).
- **Grants:** checklist P3/P3c.
- **`ensure_rls` and `on_auth_user_created`:** exact definitions read from the backup archive's object definitions, no table data.

**Test result (executed):** 8 files, 179 assertions, 0 failures. Data preserved across migrations, rollback and re-apply.

**Deliberately not implemented (decision-dependent):** U1/U2 links and legacy copy; new approval statuses; workflow functions and triggers; RLS and grant changes; audit hardening (A2, A3, A4, A5, A6, A7, A8, A9).

---

## 2c. Decision Batch 2: A2–A7 (2026-11-07)

Recorded on the project team's instruction in the working session on 2026-11-07. As with Batch 1, no approver name was given, so the named sign-off is left for the approver to complete.

| # | Decision (as instructed) | Report recommendation | Questions answered |
|---|---|---|---|
| **A2** | "Use Supabase JWT + RLS for normal user-specific reads. Critical workflow operations must go through authenticated backend APIs and narrowly scoped, secure database functions. Never expose service_role keys to Flutter or n8n." | Same (A + B + C; D none) | A2-Q2 (Flutter may read its own data directly), A2-Q3 (revoke direct client writes on approvals, playbook_runs, remediation_executions, audit_logs), A2-Q5 (functions plus constraints/triggers) |
| **A3** | "Use one authoritative approval system. Each approval must be linked 1:1 to a playbook_run. Enforce immutable approval decisions, requester/approver separation, idempotency and duplicate execution prevention." | Same | U2 (link direction `approvals.playbook_run_id`) |
| **A4** | "Require human approval for every remediation action initially. No automatic remediation execution without approval. All four action types must follow this rule." | Stricter than the report (no unprotected types) | A4-Q1 (all four protected), A4-Q2 (the no-approval restart playbook still needs approval; its row is unchanged), R8 (moot) |
| **A5** | "Use a dedicated automation identity and authenticated backend APIs. Secure both n8n-to-backend and backend-to-n8n communication with signed authentication and replay protection. No direct database access or service_role key for n8n." | Same | A5-Q1 (`automation` role value), A5-Q3 (HMAC with replay protection) |
| **A6** | "Implement notification management in the backend notification module. Support in_app, push, email, slack and discord. Keep provider credentials on the backend." | Same; channel set extended | A6-Q1 (fold into the backend), R4 (channels), R6 (code location: backend) |
| **A7** | "Implement append-only audit logging with database-enforced protections. Derive actor identity from authenticated context, prevent client updates/deletes, and ensure critical operations and audit records are committed atomically. Keep incident_events separate for incident timelines." | Same | A7-Q1 (fail closed), A7-Q4 (no back-fill: nothing invented), A7-Q6 (timeline in scope) |

### Sub-answers given during implementation (2026-11-07)
These were asked because each one changes the code and none was answered by the decisions above.

| Question | Answer |
|---|---|
| **A3-Q1** Who may approve | **Admin and operator**, never for their own request |
| **A3-Q3** Who completes running runs | **n8n, plus a manual override** by admin/operator with a required reason (audited) |
| **A3-Q4** Expiry and timeouts | **Not now.** Recorded as open. |
| **A7-Q3** Audit actor FK | **Remove the FK, keep the ID** (applied to `audit_logs` and `incident_events`) |

### Consistency check (Batch 2)
| Checked against | Result |
|---|---|
| A1 | **No conflict.** JWT + RLS primary; backend checks as a second layer; no service_role in Flutter or n8n. |
| D-001 / D-002 | **Consistent.** No privileged key anywhere; the n8n path uses a JWT identity. The backend guard test `no-privileged-key.test.ts` still passes. |
| D-004 / D-007 / D-008 | **Consistent.** CLI migration layout, synthetic data only, historical SQL untouched. |
| D-009 | **Consistent.** Nothing remote was touched. |
| Report §9.2 conflicts | A3 vs A8 legacy copy: no copy was made (legacy rows stay). A7 vs FK SET NULL: resolved by A7-Q3. A5 vs `admin_update_user_role`: the function is unchanged, and a trigger makes `automation` owner-only. A2 vs current backend: **release gate** (handover §1a). A3 vs admin-only approvals RLS: the policy now includes operators. |
| Teammate work | Existing migrations, the baseline and backend controllers are **unchanged**. Test suites 01–08 were updated only where an approved decision changes the asserted behaviour. Suite 07 was designed to be flipped. |

## 2d. Implementation record, Batch 2 (2026-11-07)

Local only: a throwaway PostgreSQL 18.6 cluster on 127.0.0.1 with synthetic data. **Nothing was applied to staging or production. Nothing was pushed.**

| File | Content |
|---|---|
| `supabase/migrations/20261107000400_automation_identity.sql` | A5: role value, owner-only role guard, `current_app_role`, `require_app_role`, nonce store + `consume_automation_nonce` |
| `…000500_trusted_audit_and_timeline.sql` | A7: actor FKs dropped, append-only/no-truncate triggers (all roles), `log_audit_event`, `write_incident_event`, `add_incident_event`, redaction, no client audit INSERT, timeline read policy |
| `…000600_notifications.sql` | A6: channel CHECKs, own-inbox/device reads, `register_device_token`, `unregister_device_token`, `mark_notification_read`, `create_notification`, `claim_notification_deliveries`, `record_notification_delivery` |
| `…000700_approval_workflow.sql` | A2/A3/A4: `approvals.playbook_run_id` (1:1), `cancelled`, separation CHECKs, idempotency key, one-active-run index, immutable decisions, `request_playbook_run`, `decide_approval`, `cancel_approval`, `cancel_playbook_run`, `start_playbook_run`, `complete_playbook_run`, `record_ai_analysis`, `record_recovery_check`, revoked direct writes, read policies |
| `database/rollback/…000400–000700.down.sql` | Guarded rollbacks: each refuses to run if it would lose data |
| `database/tests/sql/09–12` | New suites (A5, A3/A4, A7, A6); 01–08 updated per decision |
| `backend/src/middleware/machine-auth.ts`, `backend/tests/machine-auth.test.ts` | A5: HMAC signing/verification, 5-minute window, nonce replay protection (memory and database stores), fail closed |

| `…000800_audit_coverage_and_redaction.sql` (+ rollback, suite 13) | Final-review fixes. **#1:** after client audit INSERT was revoked, direct-write actions (incidents, postmortems, playbooks, integrations, role changes) were no longer audited; triggers now audit them atomically, with the actor from the JWT; status changes go to the timeline. **#2:** run/automation payloads are redacted recursively for every writer. |

**Results:** database 13 files, 325 assertions, 0 failures. Data preserved across rollback, re-apply and guard probes. Backend 69 tests, 0 failures; `tsc` clean.

**Data:** no existing row is modified by any migration (verified by checksums). Legacy rows are kept as they are (A3-Q5/U1 open).

---

## 3. Consistency check summary

| Checked against | Result |
|---|---|
| A1 (approved) | **No conflict.** D-001 and D-002 apply A1's "user JWT + RLS primary; no service_role in Flutter or n8n"; D-003 to D-005 are process decisions. |
| A2 (pending) | D-001 and D-002 answer two sub-questions. A2 stays pending (A2-Q2 to A2-Q5). |
| A3–A7 (pending) | Not decided by Batch 1. No conflict; D-001 removes service_role as an option for A5/A6 machine access, which matches the report's recommendations for both. |
| A8–A10 (proposed) | Not accepted (Q-X1 open). D-004/D-005 match the report's A10 recommendation and are recorded independently. |
| U1–U12 | No conflict. |
| U13 | **Narrowed, not closed:** method = Supabase CLI; execution identity still unverified. |
| Implementation blocker | Unchanged. Batch 1 doesn't approve any SQL. |

---

## 4. Staging project requirements (D-005, D-004)

Nothing below has been checked against the Supabase account. Items marked **[UNKNOWN]** need an answer from the account owner.

### 4.1 Access and account
| Requirement | Status |
|---|---|
| A Supabase account with permission to **create projects** in the organization that owns production (or a separate organization) | Organization decided: `AI-DevOps-CommandCenter` (D-009). The team leader's create-project permission is not verified here **[UNKNOWN]**. |
| Plan and billing that allow an additional project; cost approval | **[UNKNOWN]** (A10-Q1) |
| A Supabase **personal access token** for the CLI (`supabase login`), held by the person running migrations and never committed | Not yet created; storage method **PENDING** (D-009, A2-Q4) |
| The staging **database password**, stored in a secret store | Not yet created; storage method **PENDING** (D-009, A2-Q4) |
| An owner who approves staging creation and controls access | **Decided:** the current project team leader (D-009). Individual access assignments **PENDING**. |

### 4.2 Workstation and tooling
| Requirement | Status |
|---|---|
| Supabase CLI installed, with its version pinned and recorded | **Not installed** [V] |
| Docker, needed by CLI commands that use a local database (local stack, diff/shadow database) [A]; to be confirmed for the CLI version chosen | Docker 29.5.3 installed [V] |
| PostgreSQL client tools for backup/restore verification | Version to match the server (live server is PostgreSQL 17.11; the backup was made with pg_dump 18.6 [R]) |
| `supabase init` (creates `supabase/config.toml`) and `supabase link` to **staging** first | Roadmap Phase 3/4; not done |

### 4.3 Staging configuration to match production
| Item | Note |
|---|---|
| PostgreSQL major version | Must match production (17) [R]. |
| Region | Staging: `ap-southeast-1` (Singapore), **proposed** (D-009). Production region not recorded **[UNKNOWN]**. |
| Auth settings | Email/password provider, site URL and redirect URLs (password reset), and the GitHub provider if used (U10). Staging redirect URLs must point at staging app builds. |
| Database-level objects **not in the `public` schema export** | The `ensure_rls` event trigger [R] and the `on_auth_user_created` trigger on `auth.users` [R] aren't in `public-schema.sql` [V]. The baseline and staging setup must include and verify them explicitly. |
| Extensions | None are created in the `public` export [V]. Any in other schemas (e.g. for scheduling, A9-Q1) is **[UNKNOWN]**. |
| Default privileges | Verify on staging that P3b-equivalent default ACLs apply. They depend on which role creates objects (U13 identity). |
| Keys and secrets | Separate publishable key, JWT settings and secrets for staging; backend, n8n and mobile builds use staging values only. |

### 4.4 Data for staging – decision needed
- **Backup contents [V, schema names only]:** the existing backup is a full-database dump. It includes the `auth` (27 tables), `public` (18), `storage` (10), `realtime` (2) and `vault` (1) schemas. Table contents were not opened.
- **Decided by D-007 (§2a): synthetic test data only; the backup is not restored into staging.** The options that were considered:
  - restoring it into staging copies **real user accounts and personal data** to staging;
  - a schema-only restore with separately created test users means `profiles.id → auth.users` must be satisfied by those users.
- **Prerequisite:** restoring Supabase-managed schemas (`auth`, `storage`, `realtime`, `vault`) into another project needs a verified procedure **[UNKNOWN]**.
- **Not proven:** the backup has never been test-restored and contains no grants [R]. A fresh backup plus a roles/grants dump is still required (roadmap Phase 4).

---

## 5. D-003 pre-copy inspection (performed 2026-11-07, read-only)

### 5.1 Source
| Commit (on `feature/backend-api`) | Files | Change |
|---|---|---|
| `fff81bf` docs(database): add Phase 19 security and migration audit | 4 Phase 19 documents | +1,498 |
| `56c6b82` docs(database): record A1 hybrid architecture approval | same 4 documents | +133 / −33 |
| `030df62` docs(database): add A2-A7 architecture decision report | `A2_A7_ARCHITECTURE_DECISION_REPORT.md` | +796 |

- These three commits change **only** files under `database/` [V].
- Merge base of the two branches: `9aa3a0d` (initial structure) [V].
- `feature/backend-api` is 3 commits ahead of `origin/feature/backend-api`: these three documentation commits have **not been pushed** [V].

### 5.2 File-level conflicts
| File | On this branch? | Conflict |
|---|---|---|
| `PHASE19_FINAL_VERIFICATION_REPORT.md` | No | None |
| `MIGRATION_MAPPING.md` | No | None |
| `MIGRATION_EXECUTION_PLAN.md` | No | None |
| `SECURITY_AND_DATA_PRESERVATION_CHECKLIST.md` | No | None |
| `A2_A7_ARCHITECTURE_DECISION_REPORT.md` | No | None (inclusion: B1-1) |
| `database/README.md` | Yes | Identical on both branches [V]. Not touched. |
| `COMPLETE_DATABASE_IMPLEMENTATION_ROADMAP.md`, `DATABASE_DECISION_REGISTER.md` | Yes (this branch only) | Not in the source; no overlap |

### 5.3 Content conflicts (wording, not file collisions)
1. **"Current branch" means `feature/backend-api`.** In the Phase 19 report (findings C10, C15) and the A2–A7 report (header "Branch at time of audit: `feature/backend-api`"; §2.1 "Current branch `backend/src/lib/supabase.ts`…"), "current branch" refers to `feature/backend-api`, which uses service_role. On `feature/database-implementation` the backend has **no** service_role [V]. Read on this branch without context, those lines would be misleading.
   - **Handling:** the originals are copied **unchanged**. This register and a short `database/README.md` note (Phase 3, if approved) explain that the "current branch" in those documents is `feature/backend-api`.
2. **References to the review file.** The roadmap lists `database/A2_A7_REVIEW_2026-11-07.md` as a source, but that file doesn't exist on any branch [V]. The roadmap already says so. Nothing to copy.
3. **Record IDs.** The Phase 19 documents contain partial record UUIDs (e.g. `fdea11c4…`) and table counts. No credentials, keys, database URLs or row contents were seen in the documents read for this inspection. A final secret scan is part of the copy step.

### 5.4 Proposed copy method (not executed)
- **Recommended: cherry-pick `fff81bf`, `56c6b82` and `030df62`** (in that order) onto `feature/database-implementation`. This keeps the original commit messages, authorship and history, needs no branch switch and changes no content.
  - **Alternative:** `git checkout feature/backend-api -- database/<file>` followed by a new commit. This loses the per-commit history.
- **Not included:** the A1 backend code on `feature/backend-api` (`28b4190`).
- **Committing:** under the session rules, the copy creates commits only when the team explicitly asks for one. The copy can be staged for review without a commit.

### 5.5 Copy performed (2026-11-07, Phase 3 step 1)
- **Command:** `git cherry-pick -x fff81bf 56c6b82 030df62`. It completed with no conflicts.

| New commit | Original | Files |
|---|---|---|
| `41b6772` | `fff81bf` | 4 Phase 19 documents added |
| `bb11fdb` | `56c6b82` | same 4 documents updated (A1 approval) |
| `55c9a1b` | `030df62` | `A2_A7_ARCHITECTURE_DECISION_REPORT.md` added |

- **Content check:** all five files are **byte-identical** to `030df62` (same git blob IDs).
- **Commit metadata:** original authorship and dates are kept. `-x` added a "(cherry picked from commit …)" line to each commit message.
- **Scope check:** the only paths changed relative to `d01017a` are those five files.
- **Wording:** the "current branch" ambiguity (§5.3) is explained in a separate file, `database/HISTORICAL_CONTEXT_NOTE.md`. The originals are not edited.
- **Not pushed.**

---

## 6. Historical SQL files (D-004)

| File | Location | Status |
|---|---|---|
| `database/schema.sql` | `origin/feature/database` (`12101a2`, 2026-10-27) | **Historical.** Defines 12 of the 18 live tables. Includes a `playbook_runs` `updated_at` trigger that doesn't exist live, and that table has no `updated_at` column [V]. **Not a baseline.** |
| `database/migrations/001_align_with_proposal.sql` | `origin/feature/database` | **Historical.** Probably applied to live, judging by matching constraint and playbook names [A]; never verified. **Not a baseline** and not copied into `supabase/migrations/`. |
| `../database-backups/public-schema.sql` | Outside the repository | **Reference export** of the live `public` schema (structure only). It doesn't cover database-level objects (§4.3) or grants [R]. Input to the baseline, not the baseline itself. |

All three stay unchanged where they are. Bringing `schema.sql` and `001` onto this branch for reference is **not** decided (open item B1-3).

---

## 7. Remaining open questions after Batch 1

| # | Question |
|---|---|
| Q-X1 | Accept A8, A9, A10 into the register? |
| A2-Q2 to A2-Q5 | Flutter direct access beyond Auth (= R5); revoking direct client writes; secret store per environment; trigger/constraint enforcement option. |
| A3-Q1 to A3-Q7 | Approver roles, the deadlocked approval, manual completion, durations, legacy approval with no run, two-person approval, the n8n trigger step. |
| A4-Q1 to A4-Q4, R8 | Protected action types, Test Restart Playbook, allow-list vs block-list, who may switch off approval. |
| A5-Q1 to A5-Q5 | `automation` role, provisioning and rotation, the n8n → backend method, credential holder, the backend → n8n webhook. |
| A6-Q1 to A6-Q3, R6 | Fold notifications into the backend or not; where its code lives; who may notify other users. |
| A7-Q1 to A7-Q9 | Fail-closed audit, retention, actor FK, back-fill, external store, scope extension, triggers for direct writes, `incident_logs` reuse, marking legacy audit rows. |
| A8-Q1 to A8-Q5, A9-Q1 to A9-Q3, A10-Q3 to A10-Q5 | If Q-X1 accepts them. |
| A10-Q1 (part) | Staging availability, plan and cost (§4.1). |
| U1–U12 | Unchanged (committed plan). |
| U13 (identity) | Verify the Supabase CLI execution identity, read-only, on staging and later production. |
| R3, R4, R5, R9, R10, R11 | Mobile-only screens; notification channels; mobile data path; database test tool; `service_name` vs `service_id`; severity and root cause. |
| ~~B1-1 to B1-4~~ | Decided as D-006 to D-009 (§2a). |
| **D-009 confirmation** | Owner decided (team leader). **Still open:** credential storage method (CLI token, database password, API keys), individual access assignments, final confirmation of the proposed project name and region. Must be recorded before any CLI connection. |
| **B1b-1** | Is a restore test of the **production** backup still required (stage 2), and if so, where (local, access-controlled)? Staging uses synthetic data only (D-007). |
| **B1b-2** | Who owns the migration log (A10-Q4)? |
| **B2-1** | Confirm that the blocker allows preparing and testing migrations **locally** (done, §2b), while any remote application stays blocked. |
| **R13** | Action type names: the brief says `restart_service` / `rollback_deployment` / `scale_service` / `circuit_breaker`; the database stores `restart` / `rollback` / `scale` / `circuit_breaker`. Recommendation: keep the stored values (no data change) and map labels in the app. |
| **R14** | Confirm the design choices made inside migration 000200 (from the committed mapping): `RESTRICT` toward incidents, investigations and runs; `SET NULL` for actors and device tokens; `CASCADE` from notifications to deliveries. They are revisable until the migration is applied remotely. |

### 7.1 Exact questions blocking P5 (database functions, triggers, RLS)

Each P5 item stays unimplemented until its question is answered. Recommendations are in `DATABASE_TEAM_HANDOVER.md` §7.

| P5 item | Question for the team leader |
|---|---|
| Revoke direct client writes on `approvals`, `playbook_runs`, `remediation_executions`, `audit_logs`; definer functions | A2-Q3 and A2-Q5: approve "functions for transitions + constraints/triggers for invariants"? |
| `request_playbook_run`, `decide_approval`, cancel functions, approval link and statuses | A3-Q1 (who approves), U2 (link direction), A3-Q4 (expiry/timeout), A3-Q5 (legacy approval with no run) |
| Protected-playbook rule | A4-Q1 and R8: allow-list or block-list? Is any action type ever approval-free? |
| `start/complete_playbook_run`, `automation` role, machine endpoints | A5-Q1 to A5-Q5 |
| `register_device_token`, `create_notification`, delivery writes | A6-Q1 to A6-Q3, R6 |
| `log_audit_event`, append-only/TRUNCATE guards, `incident_events` access, actor FK | A7-Q1, A7-Q3, A7-Q6 to A7-Q9 |
| `update_incident_status`, recovery rule | U11 (recovery rule), A3 |
| Legacy remediation copy, soft delete, actor types | Q-X1, then U1, A8-Q5, A9 |

---

### 7.2 Open after Batch 2 (2026-11-07)
- **B3-1 (release gate):** the backend team switches approvals, playbook runs, remediation and audit writes to the new functions in the same release as 000500/000700 (handover §1a).
- **A5-Q2 / A2-Q4:** provisioning, rotation and revocation of the automation identity, and where the backend stores its credentials and the signing secret.
- **A3-Q2:** the live deadlocked approval (an operator can now decide it, or the admin can cancel it).
- **A3-Q4:** expiry and timeouts (deferred).
- **A3-Q5 / U1:** legacy rows.
- **U11:** incident transitions and the recovery rule (GAP-07/08).
- **A6-Q3:** humans notifying others (currently not allowed; functions and automation only).
- **A9-Q2:** human-entered AI analysis (currently automation only).
- **Q-X1, A8-Q5, A9 actor types, R13, D-009 credentials.**

## 8. Change log

| Date | Change |
|---|---|
| 2026-11-07 | Final review fixes: migration 000800 (audit coverage of direct writes; recursive payload redaction), rollback, suite 13; suite 05 count updated. 325 DB assertions, 0 failures. Not pushed. |
| 2026-11-07 | **Decision Batch 2:** A2–A7 approved (§2c), with sub-answers A3-Q1, A3-Q3, A3-Q4 and A7-Q3. Blocker lifted for local work only. Implemented as migrations 000400–000700 with guarded rollbacks, suites 09–12 and backend `machine-auth.ts` (§2d). Local tests: 304 DB assertions and 69 backend tests, 0 failures. No remote database accessed; not pushed. |
| 2026-11-07 | Implementation record §2b (P1 backend, baseline, additive migrations, local tests: 179 assertions passing). New open items B2-1, R13, R14 and the P5 question table §7.1. No remote database accessed. |
| 2026-11-07 | D-009 ownership decision recorded: team leader as owner; organization `AI-DevOps-CommandCenter`; proposed name `devops-command-center-staging` and region `ap-southeast-1`; minimum access; synthetic data only. Credential storage and access assignments pending. No project created; no CLI link; no database accessed. |
| 2026-11-07 | Batch 1b recorded (D-006 to D-009). Phase 3 step 1 performed: cherry-picked `41b6772`, `bb11fdb`, `55c9a1b` (from `fff81bf`, `56c6b82`, `030df62`). `HISTORICAL_CONTEXT_NOTE.md` added. Not pushed. No SQL executed, no Supabase access, no CLI installed. |
| 2026-11-07 | Register created. Decision Batch 1 recorded (D-001 to D-005). A8–A10 definitions quoted. D-003 pre-copy inspection, staging requirements and historical SQL status recorded. No SQL executed; no live database or Supabase access; no application code or migrations changed. |
