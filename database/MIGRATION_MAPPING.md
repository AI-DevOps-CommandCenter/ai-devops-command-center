# Migration Mapping – Existing Schema → Approved 18-Table Target

**Status:** Draft for review. No SQL has been written or executed.
**Labels:** [V-LIVE], [V-BACKUP], [V-SCHEMA] = verified · [ASSUMPTION] · [RECOMMENDATION] · [DECISION NEEDED]

> The approved target design gives the **table list and capabilities**, not the column definitions.
> Columns listed as **"proposed"** are recommendations for review, not part of the approved design.

## Architecture decision status

> **⛔ NO MIGRATION SQL OR LIVE DATABASE CHANGES UNTIL A2–A7 ARE ALSO APPROVED.**

| Decision | Status | Effect on this mapping |
|---|---|---|
| **A1** Canonical backend | **APPROVED 2026-11-07** – hybrid architecture, base `origin/feature/backend-api-database`, user-token + Supabase RLS as the primary security model (report §11) | The mapping must stay compatible with that branch's table usage. It writes incidents with free-text `service_name` (relevant to U6) and writes `remediation_executions` directly (relevant to U1). Critical rules on `approvals`, `playbook_runs`, remediation and `audit_logs` are to be enforced in the database, not only in the backend. **Not implemented.** |
| A2 Privileged mechanism / final grant–RLS boundary | **PENDING** | Determines the explicit grants for each target table (stage 7). |
| A3 Approval authority | **PENDING** | Determines the `approvals` ↔ `playbook_runs` link (§2.9, §2.10). |
| A4 No-approval execution rules | **PENDING** | Determines the `requires_approval` / protected-playbook handling (§2.8). |
| A5 n8n identity | **PENDING** | Determines who writes `automation_runs` (§2.18). |
| A6 Notifications | **PENDING** | Determines the `notifications` / `notification_deliveries` / `device_tokens` access (§2.12–§2.14). |
| A7 Trusted audit logging | **PENDING** | Determines the write path for `audit_logs` (§2.16). |

The table-by-table mapping below is unchanged by A1. A1 decides **where** the rules are enforced, not **how** existing data is mapped.

## Guiding rules

1. **Additive first.** Add tables and nullable columns before anything else. Nothing is renamed or dropped in the same step that copies data.
2. **Preserve IDs.** Every migrated record keeps its original UUID.
3. **No invented data.** Missing values stay NULL. No timestamps, services, analyses or approvals are fabricated.
4. **No silent discards.** Every existing record is either kept in place, copied with a recorded source, or explicitly flagged for review.
5. **Legacy tables are retained** (read-only) until the owner signs off.
6. **New validation applies to new writes.** Existing historical rows that break new rules are documented, not rewritten.

---

## 1. Summary

| # | Target table | Source | Action | Rows to carry |
|---|---|---|---|---|
| 1 | profiles | profiles | Keep, extend | 2 |
| 2 | services | services | Keep, extend | 2 |
| 3 | deployments | deployments | Keep | 0 |
| 4 | incidents | incidents | Keep, extend | 3 |
| 5 | **incident_events** | incident_logs (0 rows) | **Create**, map columns | 0 |
| 6 | investigations | investigations | Keep, extend | 4 |
| 7 | ai_analyses | ai_analyses | Keep, add link | 0 |
| 8 | playbooks | playbooks | Keep | 5 |
| 9 | playbook_runs | playbook_runs **+ remediation_executions** | Keep, extend, copy 1 record | 1 + 1 |
| 10 | approvals | approvals | Keep, add run link | 1 |
| 11 | recovery_checks | recovery_checks | Keep, add run link | 0 |
| 12 | notifications | notifications | Keep (inbox) | 0 |
| 13 | **notification_deliveries** | notifications (delivery columns) | **Create** | 0 |
| 14 | device_tokens | device_tokens | Keep | 0 |
| 15 | integrations | integrations | Keep | 0 |
| 16 | audit_logs | audit_logs + audit_log (0 rows) | Keep, harden | 24 |
| 17 | postmortems | postmortems | Keep | 3 |
| 18 | **automation_runs** | — | **Create** | 0 |

**Legacy tables retained temporarily:** `incident_logs`, `audit_log`, `remediation_executions`.

---

## 2. Table-by-table mapping

### 2.1 profiles ← profiles (2 rows)

| Source column | Target column | Transformation |
|---|---|---|
| id | id | None. Keep FK → `auth.users(id)`. |
| full_name | full_name | None (both currently NULL; do not fill in). |
| email | email | None. |
| role | role | **None. Roles must not change.** Values: user/operator/admin. |
| created_at, updated_at | same | None. |
| — | avatar_url *(proposed)* | NULL for existing rows; filled from GitHub metadata on future sign-ins. |

- **FK changes:** none.
- **Auth relationships [V-BACKUP]:** `2f826d1c…` (admin, email provider) and `5b41add3…` (operator, email provider). Both IDs exist in `auth.users`, one profile each.
- **Function change (proposed):** `handle_new_user()` should read `full_name`, falling back to `name` (GitHub provides `name`/`user_name`).
- **Manual review:** decide how a GitHub sign-in with an already-used email behaves (see report S13).

### 2.2 services ← services (2 rows)

| Source | Target | Transformation |
|---|---|---|
| all columns | same | None. |

- Status vocabulary unchanged: healthy, degraded, down, unknown.
- [RECOMMENDATION] Add a unique rule on (name, environment). Current data complies: two different names, both `development`.
- **Manual review:** none.

### 2.3 deployments ← deployments (0 rows)

- No data. Columns unchanged. Status vocabulary unchanged: pending, running, success, failed, cancelled.

### 2.4 incidents ← incidents (3 rows)

| Source | Target | Transformation |
|---|---|---|
| id, title, description, severity, status, source, detected_at, acknowledged_at, resolved_at, created_at, updated_at, created_by, environment | same | None. |
| service_id | service_id | **Stays NULL for all 3.** Not auto-matched. |
| service_name | service_name *(retained as legacy text)* | None. Keep the original text for history. |
| deployment_id | deployment_id | None (all NULL). |

- **Status mapping:** unchanged (open, investigating, identified, mitigating, resolved, closed).
- **FK changes (proposed):** change the child-table FKs that point at incidents from `ON DELETE CASCADE` to `ON DELETE RESTRICT`, so deleting an incident cannot destroy approvals, runs or postmortems. [RECOMMENDATION] Add an `archived_at` column for soft deletes.
- **Manual review:**
  - `6fc9b9e2…` "High CPU Usage", service_name "Payment Service": there is no matching service. [DECISION NEEDED] Create a real service record, or leave it unlinked?
  - `882078b5…` and `b32e62c7…`, service_name "Test Service": same question.
  - Two incidents are `investigating` with no `acknowledged_at`. Leave it NULL; do not invent a time.

### 2.5 incident_events ← incident_logs (0 rows) — **CREATE**

Proposed columns and mapping:

| incident_logs | incident_events (proposed) | Transformation |
|---|---|---|
| id | id | Keep. |
| incident_id | incident_id | FK → incidents, `ON DELETE RESTRICT`. |
| — | event_type | `'log'` for anything copied from incident_logs. Others: status_change, comment, investigation, approval, remediation, recovery, notification. |
| source | source | None. |
| log_level | level | info/warning/error/critical (same values). |
| message | message | None. |
| metadata | metadata | None. |
| — | actor_id | NULL for migrated rows; FK → profiles. |
| logged_at | occurred_at | Rename. |
| — | created_at | `now()` at insert. |

- **Rows to move:** 0.
- [DECISION NEEDED] Should incident timelines be backfilled from the 24 audit entries? Recommended answer: **no**. Keep audit history as the source and do not create derived records during migration.
- `incident_logs` is retained as legacy until sign-off.

### 2.6 investigations ← investigations (4 rows)

| Source | Target | Transformation |
|---|---|---|
| id, incident_id, status, summary, root_cause, evidence, ai_model, created_at | same | None. |
| — | created_by, started_at, completed_at, updated_at *(proposed)* | NULL for existing rows (not invented). |

- **Status mapping:** unchanged (pending, running, completed, failed).
- **FK changes:** incident FK → `ON DELETE RESTRICT`.
- **Manual review:**
  - `f6f96079…` and `b60a7855…` (same incident, same root cause). **Not duplicates by ID**; keep both. [DECISION NEEDED] Mark either as test data?
  - `7d5ca2b2…` has been `running` since 2026-11-05. Leave the status as-is; review whether it is stale.
  - `157a8a06…` is a `pending` security test.

### 2.7 ai_analyses ← ai_analyses (0 rows)

| Change | Detail |
|---|---|
| Add `investigation_id` *(proposed)* | Nullable FK → investigations. |
| Severity values | Add `info` so they match incidents. |
| Confidence | Unchanged (0–1). |

- **No data to move.** [RECOMMENDATION] Do **not** create ai_analyses rows from the 4 investigations, because confidence and recommended action would have to be invented.

### 2.8 playbooks ← playbooks (5 rows)

| Source | Target | Transformation |
|---|---|---|
| all columns | same | None. **`enabled` values must not change.** |
| configuration.approval_required | — | Keep inside the JSON (no rewrite). `requires_approval` becomes the only value that counts. |
| — | is_protected *(proposed)* | [DECISION NEEDED] See below. |

Records [V-BACKUP]:

| ID | Name | action_type | enabled | requires_approval |
|---|---|---|---|---|
| `de8e209e-4bf1-4272-ba0f-8e3a481f3461` | restart | restart | false | true |
| `9777c280-b8cb-4947-9e4f-e44edb99948d` | rollback | rollback | false | true |
| `a67179a1-46b9-4296-bdf6-a8a1b06834d7` | scale | scale | false | true |
| `e5524ab8-06eb-40de-af36-88d84d806c87` | circuit_breaker | circuit_breaker | false | true |
| `27041cdf-89c8-4a57-bbe9-233ef5acfe4f` | Test Restart Playbook | restart | **true** | **false** |

- **FK:** `playbook_runs.playbook_id → playbooks` stays `ON DELETE RESTRICT`.
- **Manual review:** [DECISION NEEDED] The enabled test playbook allows restarts without approval. Should protected status come from `requires_approval` alone, or should certain action types (e.g. restart/rollback) always require approval?

### 2.9 playbook_runs ← playbook_runs (1 row) + remediation_executions (1 row)

**Existing column changes (proposed):**

| Column | Change |
|---|---|
| approval_id | Nullable FK → approvals. Alternatively the link lives only on `approvals.playbook_run_id` (see 2.10). [DECISION NEEDED] Pick one direction. |
| automation_run_id | Nullable FK → automation_runs. |
| legacy_source, legacy_source_id | Record where migrated rows came from (e.g. `remediation_executions`). |

**Existing row `e48ca6e7-81d6-4ab7-9c29-354b9d0127e7`:** kept unchanged. Status stays `pending_approval`. It is **not** linked to approval `fdea11c4…`, because they are on different incidents. **Manual review:** the run has no approval row and its playbook (`restart`) is disabled. It cannot run under the new rules until a human decides what to do.

**Copy of `remediation_executions` → playbook_runs** [DECISION NEEDED: or → automation_runs]:

| remediation_executions | playbook_runs | Transformation |
|---|---|---|
| id `108d5a0d…` | id | **Same UUID** so the audit entries still point to it. |
| incident_id `6fc9b9e2…` | incident_id | None. |
| playbook_id `27041cdf…` | playbook_id | None (NOT NULL is satisfied). |
| triggered_by `2f826d1c…` | requested_by | Rename. |
| — | approved_by | NULL. No approval exists; do not invent one. |
| — | approval_required | `false`, copied from the playbook's current `requires_approval`. |
| status | status | **Status mapping below.** |
| input_data | request_payload | None. |
| output_data | result_payload | None. |
| created_at | requested_at | Rename. |
| — | approved_at | NULL. |
| started_at, completed_at | same | None. |
| — | legacy_source | `'remediation_executions'`. |

**Status mapping `remediation_executions` → `playbook_runs`:**

| Source | Target | Rows affected |
|---|---|---|
| pending | **manual review** (no clean equivalent) | 0 |
| running | running | 0 |
| succeeded | **success** | 1 |
| failed | failed | 0 |
| cancelled | cancelled | 0 |

- The copied row must be inserted **before** the new "approval required" and "playbook enabled" validation triggers exist, or those triggers must explicitly let legacy-flagged rows through. Otherwise the copy will be rejected.
- `remediation_executions` stays as a read-only legacy table until sign-off.
- Audit entries keep `entity_type = 'remediation_execution'`. Audit history is never rewritten.

### 2.10 approvals ← approvals (1 row)

| Source | Target | Transformation |
|---|---|---|
| id, incident_id, requested_by, approver_id, status, comments, requested_at, decided_at | same | None. |
| — | playbook_run_id *(proposed)* | Nullable FK → playbook_runs, `ON DELETE RESTRICT`. **NULL for the existing row.** |
| — | decision_reason *(proposed)* | NULL. |
| — | expires_at *(proposed)* | NULL for the existing row. |

**Status mapping (proposed target set):** pending, approved, rejected (existing) + `cancelled` (requester withdraws) + `expired` (time-out). No existing rows change status.

**Existing row `fdea11c4-a8af-4741-9b2e-5caa95b620d6`:**
- Incident `6fc9b9e2…`, requested 2026-11-03 15:46 by the only admin. Still pending.
- Not linked to the playbook run (different incident). [ASSUMPTION] It is **not** proven to be the approval for execution `108d5a0d…` either: that execution used a playbook that does not need approval, and nothing links the two.
- **Kept pending. It must not be approved or rejected as part of migration.**
- **Manual review:** after the deadlock fix, the owner decides whether it is decided, cancelled or left open.

### 2.11 recovery_checks ← recovery_checks (0 rows)

| Change | Detail |
|---|---|
| Add `playbook_run_id` *(proposed)* | Nullable FK → playbook_runs. |
| Add `checked_by`, `automation_run_id` *(proposed)* | Nullable. |
| Status | Unchanged: pending, healthy, unhealthy, failed. |

- No data. [RECOMMENDATION] Do **not** create a recovery check for execution `108d5a0d…`. Its recovery stays "unverified" in the report until a real check is run.

### 2.12 notifications ← notifications (0 rows) — becomes the **inbox**

| Source | Target | Transformation |
|---|---|---|
| id, user_id, incident_id, title, message, created_at, read_at | same | None. |
| channel, status, sent_at | moved to notification_deliveries | Keep the columns in place (nullable, deprecated) until sign-off; do not drop them. |
| — | type, payload *(proposed)* | New. |

### 2.13 notification_deliveries — **CREATE** (0 rows)

Proposed columns: id, notification_id (FK → notifications), device_token_id (nullable FK → device_tokens), channel (in_app/push/email/telegram), status (pending/sent/failed/delivered), provider_message_id, error_message, attempt_count, attempted_at, delivered_at, created_at.

Mapping from the old notification status (no rows affected): pending → pending, sent → sent, failed → failed, read → inbox `read_at` (not a delivery status).

### 2.14 device_tokens ← device_tokens (0 rows)

- Unchanged. Already has UNIQUE(device_token) and owner-only RLS.

### 2.15 integrations ← integrations (0 rows)

- Unchanged structure. [RECOMMENDATION] Store secrets in Supabase Vault and keep only a reference in `settings`.
- Note: one "GitHub Connection" integration (`2e748707…`) was created, updated and deleted. It now exists only in audit history [V-BACKUP].

### 2.16 audit_logs ← audit_logs (24 rows) + audit_log (0 rows)

| Source | Target | Transformation |
|---|---|---|
| audit_logs.* | same | **None. No audit row is ever modified.** |
| audit_log.user_id | actor_id | 0 rows to move. |
| audit_log.resource_type / resource_id | entity_type / entity_id | 0 rows to move. |

- **FK change:** `actor_id … ON DELETE SET NULL` conflicts with append-only history. [DECISION NEEDED] Use `ON DELETE RESTRICT` (profiles cannot be hard-deleted), or remove the FK and store the actor reference only.
- `details` and `created_at` → `NOT NULL` (stage 5), keeping the existing defaults (`'{}'` and `now()`). Verified compatible on live: 0 NULLs in either column (P4, 2026-11-07). Re-check immediately before applying.
- `entity_id` has no FK by design (it references many tables, including deleted records). Keep it that way.
- `audit_log` is retained temporarily as legacy.

### 2.17 postmortems ← postmortems (3 rows)

| Source | Target | Transformation |
|---|---|---|
| all columns | same | None. JSON in `timeline` and `action_items` is **not** normalized. |

- The UNIQUE(incident_id) rule stays (one postmortem per incident; current data complies).
- **FK change:** incident FK → `ON DELETE RESTRICT`.
- **Manual review:** all 3 belong to unresolved incidents. A future "postmortem only after resolve" rule must apply to **new** rows only.

### 2.18 automation_runs — **CREATE** (0 rows)

Proposed columns: id, workflow_name, workflow_id, n8n_execution_id (UNIQUE), trigger_type, incident_id / investigation_id / playbook_run_id (nullable FKs), status (queued/running/success/failed/cancelled/timed_out), input, output, error_message, started_at, completed_at, created_at.

- No source data. [DECISION NEEDED] Should execution `108d5a0d…` be copied here instead of into `playbook_runs`? Recommended: **playbook_runs**, because it references a playbook and an incident, and nothing shows that n8n ran it.

---

## 3. Legacy tables retained temporarily

| Table | Rows | Retire after |
|---|---|---|
| incident_logs | 0 | incident_events in use + owner sign-off |
| audit_log | 0 | Owner sign-off |
| remediation_executions | 1 | Copied row verified in playbook_runs + owner sign-off |

Retirement is a separate, later approval: first revoke write access, then rename as deprecated, and drop only after a soak period and a fresh backup.

---

## 4. Records requiring manual review

| Record | Issue |
|---|---|
| approval `fdea11c4…` | Pending, deadlocked, not linked to any action. |
| playbook_run `e48ca6e7…` | No approval row; disabled playbook. |
| remediation_execution `108d5a0d…` | Succeeded with an approval pending on the incident; no recovery check; target table decision. |
| investigation `7d5ca2b2…` | Possibly stale `running`. |
| investigations `f6f96079…` / `b60a7855…` | Similar content; test or real? |
| incidents (all 3) | Unlinked `service_name`; lifecycle gaps. |
| postmortems (all 3) | Exist for unresolved incidents. |
| playbook `27041cdf…` | Enabled, no approval needed, restart action. |
| All records | [DECISION NEEDED] Test-data policy: keep as-is, tag, or archive. |
