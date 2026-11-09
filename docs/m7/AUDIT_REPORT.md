# M7 Pre-Implementation Audit

**Author:** Thilina (M7) · **Date:** 2026-11-09 · **Branch:** `feature/github-integration`, created from `origin/feature/backend-rpc-integration` at `a195a7e`

## 1. Existing architecture

| Area | State on the base branch |
|---|---|
| Backend | Node.js + Express 5 + TypeScript (ES modules), Supabase with the caller's JWT and RLS (decision A1). No privileged key in the runtime (D-001). Zod validation, Helmet, CORS allow-list, rate limiting. |
| Tests | Vitest + Supertest. Supabase is mocked and `fetch` is blocked in `tests/setup.ts`. 121 tests in 13 files, all passing before M7's changes. |
| Database | Supabase migrations `000000`–`000800`. A2–A7 approved and implemented. |
| Notifications (A6) | Database side only: `notifications`, `notification_deliveries`, and the functions `create_notification`, `claim_notification_deliveries`, `record_notification_delivery`. Channels: `in_app, push, email, slack, discord`. Provider credentials stay on the backend. |
| n8n (other branch) | `feature/n8n-ai-investigation` (Vishwa, Tharindu). **Workflow 04 already calls the GitHub REST API directly** (commits + Actions runs) for deployment correlation. Workflow 09 posts a redacted error summary to an optional Slack/Discord webhook. |
| Mobile (other branch) | `feature/mobile-screens-data`: screens S13 Repositories, S14 Deployment details, S15 Failed pipeline job and S24 PR summary show repositories, commits, PRs and pipeline runs, but only as **hard-coded mock data**. |

## 2. Existing M7-related code

- No GitHub, Email, Slack or Discord integration code in `backend/`.
- No notification API and no notification sender worker yet (M5's tasks).
- `backend/src/controllers/admin-integration.controller.ts` allows `github`, `slack` and `discord` as integration providers (admin CRUD only, no secrets).

## 3. Ownership and conflicts

| Item | Owner | M7 action |
|---|---|---|
| Notification API, notification sender worker | Vinuka (M5) | Not built. M7 provides senders that plug into the worker. |
| Deployment correlation via GitHub (n8n 04) | Tharindu (M2) | Not duplicated. |
| n8n error webhook (09) | Vishwa (M1) | Not touched. |
| Push notifications (FCM) | Himasha (M6) | Not built. `push` deliveries get no M7 sender. |
| Repositories screens | Gayathri (UI) / Himasha (API service) | M7 provides the backend endpoints they can call. |
| `backend/src/app.ts` | shared | One additive change (mount `/api/github`), flagged for review. |

## 4. Contracts used

- **Notification delivery (approved A6, contract B.4):** worker claims rows with `claim_notification_deliveries`, sends them, records with `record_notification_delivery`. The M7 sender interface is derived from these exact row and parameter shapes, and tests check it against the migration.
- **GitHub:** no requirement existed. **Decision (Thilina, 2026-11-09):** read-only GitHub service plus authenticated `GET /api/github/*` endpoints for the mobile Repositories screens, using a fine-grained read-only token held by the backend.

## 5. Items for clarification

| # | Question | For |
|---|---|---|
| Q1 | Does the response shape in the Integration Guide §3 fit the Flutter models? | Himasha, Gayathri |
| Q2 | Worker retry policy: maximum attempts, and whether retryable failures stay pending (as in the M7 test driver) or are recorded as failed. | Vinuka |
| Q3 | Should the worker record a delivery as `failed` when its channel has no sender configured? | Vinuka |
| Q4 | Who provisions the GitHub token, the Slack/Discord webhooks and the SMTP account, and who rotates them (similar to A5-Q2)? | Team / supervisor |
| Q5 | Should GitHub repositories come from the `integrations` table (admin-managed) instead of `GITHUB_REPOSITORIES`? | Team |

## 6. Environment note

The development disk (E:) had about 5 MB free, so `npm ci` failed there with `EBADF`. Dependencies were installed on C: and linked with a directory junction (`backend/node_modules`, which is git-ignored). This doesn't affect the repository.
