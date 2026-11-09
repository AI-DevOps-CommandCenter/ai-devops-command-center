# Final Report Contribution: Integrations and Testing (Thilina, M7)

*For merging into the agreed shared final-report structure. This file covers M7's sections only.*

## 1. GitHub integration

The mobile app's Repositories screens (S13, S14, S15, S24) need repository, commit, pull-request and pipeline data. A GitHub token must never be shipped in a mobile app, so the backend reads GitHub on the app's behalf.

M7 implemented a read-only GitHub service in the Express backend. It is exposed as seven authenticated `GET /api/github/*` endpoints (repositories, commits, pull requests, pull-request detail, workflow runs, workflow jobs). The design choices:

- **Least privilege.** A fine-grained token with read-only permissions, used only by the backend.
- **Repository allow-list.** Only repositories in `GITHUB_REPOSITORIES` are served. Requests for any other repository get 404 without contacting GitHub, so the backend can't be used as a proxy to other repositories.
- **Small responses.** GitHub payloads are mapped to purpose-built objects. Author e-mail addresses and other unneeded data are dropped.
- **Resilience.** 10-second timeouts and one retry for transient failures. When GitHub reports its rate limit, the backend stops calling it until the reset time and tells the app when to retry (HTTP 503 with `Retry-After`). A 30-second cache lets many app users share one GitHub request.
- **Correct error semantics.** GitHub rejecting the backend's token is reported as 502, not 401, so the app doesn't wrongly sign the user out.

Deployment correlation during incident investigation stays in the n8n workflow (M2), which already reads GitHub directly. The two don't overlap.

## 2. Email, Slack and Discord integrations

The database team's approved notification design (decision A6) stores one delivery row per external channel. A backend worker (M5) claims pending rows, sends them and records the result. M7 implemented the sending part as three interchangeable senders behind one interface:

| Channel | Transport | Notes |
|---|---|---|
| Email | SMTP (nodemailer) | Plain-text only; header-injection-safe subject; STARTTLS required by default |
| Slack | Incoming webhook | Control characters escaped so messages can't trigger `@channel` |
| Discord | Webhook (embed) | Mentions disabled; message id returned for traceability |

Each sender returns either *sent* (with the provider's message id) or *failed* with a `retryable` flag. Rate limits, timeouts, 5xx responses and SMTP 4xx replies are retryable. Removed webhooks, rejected recipients and authentication failures are permanent. The worker can retry the first kind and record the second immediately. Error text is redacted (webhook URLs, tokens, passwords) and limited to the database column's 500 characters, and log lines contain no URLs, recipients or message text.

The sender interface is derived directly from the approved database functions, and an automated test checks it against the migration file, so a schema change that breaks it fails the build.

## 3. Integration architecture

```text
Mobile ──► /api/github/* ──► GitHubService ──► GitHub REST API (read-only)
DB (A6) ◄──claim/record── Notification worker (M5) ──► Email / Slack / Discord senders (M7) ──► providers
```

Provider credentials (GitHub token, webhooks, SMTP) exist only in the backend environment, never in the mobile app, n8n or the database (decision A6). Every integration is optional: an unconfigured channel simply has no sender, and unconfigured GitHub answers 503.

## 4. Testing methodology

Testing used three levels, all automated with Vitest:

1. **Unit tests** with a scripted fake `fetch` and a fake mail transport, covering configuration validation, error classification, message formatting, redaction and mapping.
2. **API tests** with Supertest against the real Express app (authentication mocked), covering access control, input validation and error-to-HTTP mapping.
3. **End-to-end tests** with real HTTP and SMTP traffic to local mock GitHub, Slack, Discord and SMTP servers. For notifications, a test driver follows the approved claim → send → record contract, because M5's worker wasn't available yet.

External services were never contacted by automated tests. A loopback-only guard enforces this. A separate opt-in script (`scripts/m7-sandbox-check.ts --confirm`) is provided for manual checks against sandbox accounts.

## 5. Results

On 2026-11-09 the full backend suite ran **225 tests, all passing**: 104 new M7 tests (25 GitHub unit, 19 GitHub API, 45 sender unit, 15 end-to-end) and the 121 existing tests, unchanged. The TypeScript typecheck passed. Details and the raw log are in `docs/m7/TEST_RESULTS.md` and `docs/m7/evidence/`.

Testing found one defect: rate-limit wait times used the wrong clock. It was fixed before submission.

## 6. Issues and limitations

- **Not yet verified against real services.** No sandbox credentials were available, so tests ST-01 to ST-04 haven't been run.
- **The notification worker (M5) isn't merged yet.** End-to-end notification tests use a contract driver; they should be re-run against the real worker.
- **Database round trip not run** locally (needs the PostgreSQL harness).
- The repository allow-list comes from an environment variable, not the admin-managed `integrations` table.
- The rate-limit pause and the cache are in-memory per backend process. Several instances would each keep their own.
- Slack incoming webhooks return no message id, so Slack deliveries can't be traced on Slack's side.

## 7. Future improvements

- Manage GitHub repositories through the admin Integrations screen (`integrations` table) instead of the environment.
- Use GitHub conditional requests (ETag), which don't count against the rate limit.
- Use a GitHub App instead of a personal token, for organisation-level control and automatic token rotation.
- HTML e-mail templates with a deep link to the incident in the app.
- Slack Block Kit / the Slack Web API for richer messages and message ids.
- A shared store (e.g. Redis) for the cache and rate-limit state when the backend scales out.
