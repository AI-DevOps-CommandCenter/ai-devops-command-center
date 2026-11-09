# M7 Integration Guide: GitHub, Email, Slack, Discord

**Owner:** Thilina (M7) · **Reviewer:** Vinuka (M5) · **Code:** `backend/src/integrations/`, `backend/src/routes/github.routes.ts`, `backend/src/controllers/github.controller.ts`

## 1. Architecture

```text
Flutter app ──GET /api/github/*──► Express (authenticateToken, Zod) ──► GitHubService ──► GitHubClient ──HTTPS──► api.github.com
                                                                             (allow-list)     (token, timeout, retry,
                                                                                               rate-limit pause, cache)

Database (A6) ◄─claim / record── Notification worker (M5) ──send(row)──► EmailSender   ──SMTP──►  mail server
                                                                       ├► SlackSender   ──HTTPS──► Slack webhook
                                                                       └► DiscordSender ──HTTPS──► Discord webhook
```

| File | Purpose |
|---|---|
| `integrations/http.ts` | Shared outbound HTTP: timeout, no redirects, failure classification (`timeout`, `network`, `auth`, `not_found`, `rate_limited`, `client_error`, `server_error`) with `retryable` and `retryAfterMs` |
| `integrations/redact.ts` | Removes webhook URLs, GitHub/Slack tokens, Bearer/Basic credentials and given secrets; truncates to 500 characters |
| `integrations/github/*` | Config, client, service and mappers |
| `integrations/notifications/*` | Sender contract, config, the three senders, factory |

## 2. Configuration (backend environment only)

Never commit these values. Use sandbox channels and a test repository during development.

| Variable | Required | Default | Notes |
|---|---|---|---|
| `GITHUB_TOKEN` | for GitHub | – | Fine-grained token, **read-only**: Metadata, Contents, Pull requests, Actions; only the listed repositories |
| `GITHUB_REPOSITORIES` | for GitHub | – | `owner/repo,owner/repo2`. Only these are served. |
| `GITHUB_API_URL` | no | `https://api.github.com` | HTTPS only |
| `GITHUB_TIMEOUT_MS` | no | `10000` | 1000–60000 |
| `GITHUB_CACHE_TTL_MS` | no | `30000` | `0` disables the cache |
| `SLACK_WEBHOOK_URL` | for Slack | – | Must be `https://hooks.slack.com/...` |
| `DISCORD_WEBHOOK_URL` | for Discord | – | Must be `https://discord.com/api/webhooks/<id>/<token>` |
| `SMTP_HOST`, `EMAIL_FROM` | for email | – | `EMAIL_FROM` may be `Name <addr@example.com>` |
| `SMTP_PORT` | no | `587` | |
| `SMTP_SECURE` | no | `false` | `true` for implicit TLS (port 465) |
| `SMTP_REQUIRE_TLS` | no | `true` | STARTTLS required, so credentials are never sent in plain text |
| `SMTP_USER`, `SMTP_PASSWORD` | no | – | Both or neither |
| `NOTIFICATION_SEND_TIMEOUT_MS` | no | `10000` | Per delivery attempt |

If only some of a channel's variables are set, startup fails with the name of the missing variable (never its value). If none of GitHub's variables are set, the `/api/github/*` endpoints answer **503**.

## 3. GitHub API (for the mobile app)

Every endpoint needs `Authorization: Bearer <Supabase access token>` and is read-only. Responses use the standard shape `{ success, message, data }`; lists also include `count`.

| Endpoint | Query | `data` | Screen |
|---|---|---|---|
| `GET /api/github/repositories` | – | `RepositorySummary[]` | S13 |
| `GET /api/github/repositories/:owner/:repo` | – | `RepositorySummary` | S13 |
| `GET …/:owner/:repo/commits` | `branch?`, `limit` 1–100 (20) | `CommitSummary[]` | S13, S14 |
| `GET …/:owner/:repo/pulls` | `state` open\|closed\|all (open), `limit` | `PullRequestSummary[]` | S13 |
| `GET …/:owner/:repo/pulls/:number` | – | `PullRequestDetail` | S24 |
| `GET …/:owner/:repo/workflow-runs` | `branch?`, `status?` queued\|in_progress\|completed\|success\|failure\|cancelled, `limit` | `WorkflowRunSummary[]` | S13, S14 |
| `GET …/:owner/:repo/workflow-runs/:runId/jobs` | – | `WorkflowJobSummary[]` | S15 |

**Fields** (from `github.service.ts`). All timestamps are ISO-8601 strings or `null`.

- `RepositorySummary`: `full_name, owner, name, description, default_branch, private, html_url, open_issues_count, pushed_at, updated_at`
- `CommitSummary`: `sha, short_sha, title, message, author_name, author_login, authored_at, html_url` (no author e-mail)
- `PullRequestSummary`: `number, title, state (open|closed), merged, draft, author_login, head_branch, base_branch, created_at, updated_at, closed_at, merged_at, html_url`
- `PullRequestDetail`: the summary plus `body (≤5000 chars), commits, additions, deletions, changed_files, mergeable_state`
- `WorkflowRunSummary`: `id, name, run_number, event, status, conclusion, branch, head_sha, actor_login, created_at, updated_at, run_started_at, html_url`
- `WorkflowJobSummary`: `id, name, status, conclusion, started_at, completed_at, html_url, steps[{ number, name, status, conclusion }]`

**Errors**

| Status | Meaning |
|---|---|
| 400 | Invalid parameter (includes `errors[]`) |
| 401 | Missing or invalid user token |
| 404 | Repository not on the allow-list, or GitHub resource not found |
| 502 | GitHub rejected the **backend's** token, is down, or returned an unexpected payload |
| 503 | GitHub isn't configured, or GitHub's rate limit was reached (`Retry-After` header in seconds) |

**Rate limits:** when GitHub reports a limit (403/429 with `x-ratelimit-remaining: 0` or `Retry-After`), the backend stops calling GitHub until the reset time. Identical requests within `GITHUB_CACHE_TTL_MS` share one GitHub call.

## 4. Notification sender contract (for the M5 worker)

Defined in `integrations/notifications/types.ts` and derived from migration `000600`:

```ts
import { createNotificationSenders, toRecordDeliveryParams } from "../integrations/notifications/index.js";

const senders = createNotificationSenders();               // once at startup; only configured channels

const { data: rows } = await automation.rpc("claim_notification_deliveries", { p_limit: 50 });
for (const row of rows) {
  const sender = senders.get(row.channel);                 // "email" | "slack" | "discord"
  if (!sender) { /* channel not configured: worker policy (Q3) */ continue; }
  const result = await sender.send(row);                   // never throws
  if (result.status === "failed" && result.retryable && row.attempt_count < MAX_ATTEMPTS) {
    continue;                                              // stays pending; the database re-claims it after 2 minutes
  }
  await automation.rpc("record_notification_delivery", toRecordDeliveryParams(row.delivery_id, result));
}
```

- `send()` accepts a `claim_notification_deliveries` row unchanged and returns either `{ status: "sent", providerMessageId }` or `{ status: "failed", errorMessage, retryable, retryAfterMs? }`.
- `errorMessage` is already redacted and at most 500 characters, so it is safe for `p_error_message`.
- Provider message id: SMTP `Message-ID`, the Discord message id, or `null` for Slack (incoming webhooks return none).
- `push` and `in_app` have no M7 sender.

| Case | Result |
|---|---|
| Timeout, network error, HTTP 5xx, HTTP 429, SMTP 4xx, SMTP connection errors | `failed`, `retryable: true` (429 adds `retryAfterMs`) |
| Webhook removed (404), HTTP 400/401/403, SMTP 5xx, SMTP auth failure, recipient rejected, missing or invalid recipient, wrong channel | `failed`, `retryable: false` |

**Message format**

- **Slack:** `*title*`, then the message, then `_Incident: <id>_`. `&`, `<` and `>` are escaped, so text can't trigger `<!channel>` pings.
- **Discord:** one embed (title ≤256, description ≤4096) with `allowed_mentions: { parse: [] }`.
- **Email:** plain text only. Subject `[DevOps Command Center] <title>` with line breaks removed (prevents header injection).

**Logging:** one line per failure: `[notifications] <channel> delivery <id> failed: <kind> (HTTP n)`. Logs never include webhook URLs, recipients, message text or provider responses.

## 5. Manual sandbox check (real services)

```bash
cd backend
npx tsx scripts/m7-sandbox-check.ts --confirm          # GitHub reads only
npx tsx scripts/m7-sandbox-check.ts --confirm --send   # plus one test message per configured channel
```

It reads the backend `.env`. Email also needs `M7_SANDBOX_EMAIL_TO` (a mailbox you own). It refuses to run without `--confirm`.

## 6. Changes to shared files

| File | Change |
|---|---|
| `backend/src/app.ts` | Additive: `AppOptions.github` and the `/api/github` mount (same pattern as `machine`). No existing route changed. |
| `backend/package.json`, `package-lock.json` | Adds `nodemailer@10.2.1` (exact pin, published 2026-10-22) and `@types/nodemailer@8.0.2` (dev). The lockfile diff contains only these entries. |

The backend README's environment table doesn't list the M7 variables yet. Vinuka may want to add them; this guide is the source until then.
