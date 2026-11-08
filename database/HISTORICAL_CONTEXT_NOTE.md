# Historical Context Note for the Phase 19 Documents

**Applies to:** the five documents brought onto `feature/database-implementation` on 2026-11-07 (decision D-003):

| Document | Cherry-picked as | Original commit |
|---|---|---|
| `PHASE19_FINAL_VERIFICATION_REPORT.md` | `41b6772`, `bb11fdb` | `fff81bf`, `56c6b82` |
| `MIGRATION_MAPPING.md` | `41b6772`, `bb11fdb` | `fff81bf`, `56c6b82` |
| `MIGRATION_EXECUTION_PLAN.md` | `41b6772`, `bb11fdb` | `fff81bf`, `56c6b82` |
| `SECURITY_AND_DATA_PRESERVATION_CHECKLIST.md` | `41b6772`, `bb11fdb` | `fff81bf`, `56c6b82` |
| `A2_A7_ARCHITECTURE_DECISION_REPORT.md` | `55c9a1b` | `030df62` |

The documents were copied **unchanged**; their file contents are byte-identical to the originals on `feature/backend-api`. This note adds context. It does not change, correct or override them.

---

## 1. "Current branch" in these documents means `feature/backend-api`

The documents were written while `feature/backend-api` was checked out. Wherever they say "current branch", or give a `backend/src/...` path **without** a `B` prefix, they mean **`feature/backend-api`**, not this branch.

| Location | Wording | What it refers to |
|---|---|---|
| `PHASE19_FINAL_VERIFICATION_REPORT.md` §9 intro table | "`feature/backend-api` (checked out) – service_role key" | `feature/backend-api` |
| `PHASE19_FINAL_VERIFICATION_REPORT.md` §6, S8 | "Backend uses the service-role key … `backend/src/lib/supabase.ts`" | `feature/backend-api` |
| `PHASE19_FINAL_VERIFICATION_REPORT.md` §9.2, C10 | "The current branch uses the service_role client" | `feature/backend-api` |
| `PHASE19_FINAL_VERIFICATION_REPORT.md` §9.2, C15 | "The current branch returns the (public) publishable/anon key at `/api/auth/config`" | `feature/backend-api` |
| `A2_A7_ARCHITECTURE_DECISION_REPORT.md` header | "Branch at time of audit: `feature/backend-api`" | `feature/backend-api` |
| `A2_A7_ARCHITECTURE_DECISION_REPORT.md` §2.1 | "Current branch `backend/src/lib/supabase.ts:7,15-23`" | `feature/backend-api` |

**On this branch** (`feature/database-implementation`, whose backend is `origin/feature/backend-api-database` @ `84fb81a`):
- `backend/src/lib/supabase.ts`, `backend/src/routes/auth.routes.ts` and `backend/src/routes/services.routes.ts` **do not exist** [verified 2026-11-07].
- The backend uses the publishable key plus the user's JWT, with **no service_role** [verified 2026-11-07].

## 2. The `B` prefix means this branch's backend code

Both documents define `B` as `origin/feature/backend-api-database:backend/src`:
- `PHASE19_FINAL_VERIFICATION_REPORT.md` §9: "`B` below = `origin/feature/backend-api-database:backend/src`".
- `A2_A7_ARCHITECTURE_DECISION_REPORT.md` evidence labels: "`B:` = `origin/feature/backend-api-database:backend/src/`".

That is the backend code on this branch (unchanged since `84fb81a`), so `B/…` and `B:…` references apply to this branch's `backend/src/`.

## 3. Facts that have changed since the documents were written

| Statement in the documents | Status on 2026-11-07 (later the same day) |
|---|---|
| `origin/feature/notifications` uses the service_role key (Phase 19 report §9 table; A2–A7 report §2.1, §4.1) | That branch was **force-updated** on 2026-11-07 and now contains only `notifications/README.md`. The analysed code (`43c9747`) is no longer on any branch. See roadmap C10 and open question R6. |
| A2–A7 report §0 / §12: A2-Q1, R-items not yet asked | A2-Q1, R1, R2, R7, R12 and B1-1 to B1-4 have since been decided. See `DATABASE_DECISION_REGISTER.md`. |
| `MIGRATION_EXECUTION_PLAN.md` U13: method "SQL Editor or Supabase CLI" not selected | Method selected: **Supabase CLI** (D-004). The execution identity is still unverified, so U13 stays open. |
| Rehearsal environment "local Postgres 17 or a separate Supabase staging project/branch" | **Separate staging Supabase project** selected (D-005), with synthetic test data only (D-007). |

## 4. Decision status is unchanged by the copy

The copied documents state that A1 is APPROVED, A2–A7 are PENDING and A8–A10 are PROPOSED. That remains true. The current status of every decision is maintained in `DATABASE_DECISION_REGISTER.md`.

The implementation blocker remains in force: **no migration SQL or live database changes until all required decisions in the committed A2–A7 register have been approved.**
