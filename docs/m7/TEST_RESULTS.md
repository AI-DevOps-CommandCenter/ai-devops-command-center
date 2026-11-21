# M7 Test Results: GitHub Integration and Notification Senders

**Tester:** Thilina (M7) · **Executed:** 2026-11-09 · **Branch:** `feature/github-integration`
**Environment:** Windows 11, Node.js v24.13.0, Vitest 5.0.5, TypeScript (`tsc --noEmit`)
**Evidence:** [`evidence/2026-11-09-full-suite-vitest-verbose.txt`](evidence/2026-11-09-full-suite-vitest-verbose.txt), the complete verbose output of the run reported here.

This document reports only tests that were actually executed. Every result below comes from the evidence log.

## 1. Summary

| Suite | Type | External services | Tests | Passed | Failed |
|---|---|---|---|---|---|
| `tests/github.integration.test.ts` | Unit | Fake fetch (scripted) | 25 | 25 | 0 |
| `tests/github.routes.test.ts` | API (Supertest) | Fake fetch, Supabase mocked | 19 | 19 | 0 |
| `tests/notification-senders.test.ts` | Unit | Fake fetch / fake mail transport | 45 | 45 | 0 |
| `tests/e2e/github-api.e2e.test.ts` | End-to-end | **Real HTTP** to a local mock GitHub server | 6 | 6 | 0 |
| `tests/e2e/notification-delivery.e2e.test.ts` | End-to-end | **Real HTTP/SMTP** to local mock Slack, Discord and SMTP servers | 9 | 9 | 0 |
| **M7 total** | | | **104** | **104** | **0** |
| Existing backend suites (regression) | Unit/API | Mocked | 121 | 121 | 0 |
| **Full suite** | | | **225** | **225** | **0** |

The typecheck (`tsc --noEmit`) passed with no errors.

**Mocked vs real:** every test above runs offline. The E2E tests send real HTTP and SMTP traffic, but only to mock servers on `127.0.0.1`; a guard makes any other host fail the test. **No test was run against real GitHub, Slack, Discord or an SMTP provider** (see §5).

## 2. How to reproduce

```bash
cd backend
npm ci
npx tsc --noEmit
npx vitest run --reporter=verbose
```

## 3. End-to-end test cases

**Common preconditions:** backend dependencies installed; no credentials needed. Each E2E file starts its own mock servers on random local ports.

**Notification flow under test:** mocked automation client returns rows shaped like `claim_notification_deliveries` → test-only contract driver (`tests/e2e/helpers/contract-worker.ts`, standing in for M5's worker) → real M7 senders → real HTTP/SMTP → mock provider → parameters for `record_notification_delivery`.

| ID | Name | Objective | Steps | Expected | Actual | Status |
|---|---|---|---|---|---|---|
| E2E-N01 | Deliver to all three channels | Happy path for email, Slack and Discord | Claim 3 rows (email, slack, discord), run one cycle | All 3 sent. SMTP server gets the mail (authenticated, correct subject and body). Slack gets JSON `text`. Discord gets an embed with `?wait=true` and mentions disabled. Each delivery is recorded `sent` with the SMTP Message-ID / `null` / Discord id. | As expected | **Pass** |
| E2E-N02 | Removed Slack webhook | Permanent failure handling | Slack mock answers 404 `no_service` | Recorded `failed`, `retryable: false`, message `Slack: Resource not found (HTTP 404). (no_service)`, no URL in the message | As expected | **Pass** |
| E2E-N03 | Transient Slack failure | Retry path | Slack mock answers 500. Run with attempt 1, then attempt 3 (max 3). | Attempt 1: not recorded (stays pending). Attempt 3: recorded `failed`. | As expected | **Pass** |
| E2E-N04 | Discord rate limit | Rate-limit handling | Discord mock answers 429, `Retry-After: 4` | `failed`, `retryable: true`, `retryAfterMs: 4000`, not recorded | As expected | **Pass** |
| E2E-N05 | Bounced e-mail | SMTP permanent error | RCPT answered `550` | `failed`, `retryable: false`, recorded with `550` in the message | As expected | **Pass** |
| E2E-N06 | Temporary SMTP rejection | SMTP transient error | RCPT answered `451` | `failed`, `retryable: true`, not recorded | As expected | **Pass** |
| E2E-N07 | Wrong SMTP credentials | Auth failure, secret safety | Use a wrong password; mock answers `535` | `failed`, `retryable: false`, message contains `EAUTH`; the password appears in neither the record nor the logs | As expected | **Pass** |
| E2E-N08 | Provider never answers | Timeout | Slack mock never responds; timeout 1000 ms | `failed`, `retryable: true`, `Slack: No response within 1000 ms.`, finished in under 3 s | As expected | **Pass** |
| E2E-N09 | Unconfigured channel, failed claim | Robustness | (a) No email config. (b) Claim returns DC403. | (a) Recorded `failed` with "Channel email is not configured." (b) Cycle throws and nothing is sent | As expected | **Pass** |

**GitHub flow under test:** HTTP request with a user token → Express app (auth mocked, Zod validation, routes) → `GitHubService` → real HTTP → local mock GitHub REST API → mapped JSON.

| ID | Name | Objective | Steps | Expected | Actual | Status |
|---|---|---|---|---|---|---|
| E2E-G01 | Repositories screen flow | Main data path for S13/S14/S15/S24 | Call repositories, commits, pulls, PR 214, workflow runs, jobs of run 318 | 200 responses with mapped fields, no author e-mail. GitHub receives exactly 6 GETs with `Accept: application/vnd.github+json` and `X-GitHub-Api-Version: 2022-11-28`. | As expected | **Pass** |
| E2E-G02 | Rate limit | Stop calling GitHub after a limit | Mock answers 403 with `x-ratelimit-remaining: 0` and a reset 90 s ahead; call twice | Both calls return 503 with `Retry-After` > 80. Only the first call reaches GitHub. | As expected | **Pass** |
| E2E-G03 | Revoked token | Backend token failure | Mock answers 401 | 502 "GitHub integration is misconfigured."; token not in the response | As expected | **Pass** |
| E2E-G04 | GitHub not answering | Timeout + retry | Mock never responds; timeout 1000 ms | 502 after exactly 2 attempts, in under 5 s | As expected | **Pass** |
| E2E-G05 | Cache | Shared requests | Same commits request 3 times, TTL 30 s | 3 × 200, 1 GitHub request | As expected | **Pass** |
| E2E-G06 | Access control | Allow-list and auth | Request an unlisted repository; request without a token | 404 and 401; no GitHub request | As expected | **Pass** |

## 4. Unit and API test groups

All tests passed. The exact names are in the evidence log.

| Group | Tests | What is verified |
|---|---|---|
| GitHub configuration | 9 | Disabled when unset; missing variable named without its value; allow-list parsing and de-duplication; invalid entries rejected; HTTPS-only API URL |
| GitHub client | 10 | Auth and API-version headers; one retry on 5xx/network; timeout; 401 not retried and token not logged; 404; primary and secondary rate limits pause requests until reset; cache TTL; redirects not followed |
| GitHub mapping and service | 6 | No author e-mail; merged-PR detection; workflow runs; malformed payloads rejected; allow-list (case-insensitive); exact GitHub endpoints and query parameters |
| GitHub endpoints | 19 | 401 without a token; 503 when not configured or by default; unlisted repository 404 with no GitHub call; 8 invalid-input cases → 400; data endpoints; 404/502/503 (`Retry-After`) mapping |
| Sender configuration | 14 | Empty config; all channels; 10 invalid configurations rejected (wrong webhook hosts, HTTP, partial SMTP, bad port or flag, bad timeout); secrets never in errors; only configured channels get senders |
| DB contract | 3 | `toRecordDeliveryParams` uses exactly the parameter names of `record_notification_delivery` in migration 000600; `ClaimedDelivery` matches the columns `claim_notification_deliveries` returns |
| Redaction | 2 | Webhook URLs, GitHub/Slack tokens, Bearer credentials and given secrets removed; 500-character limit |
| Slack sender | 10 | Payload and escaping; 404 / 500 / 429 / 400 / 403 / network classification; timeout; wrong-channel delivery refused without sending |
| Discord sender | 4 | Embed, mentions disabled, message id; embed limits; 429 `Retry-After`; unknown webhook permanent, URL not leaked |
| Email sender | 12 | Plain-text mail to the claimed recipient; subject header injection blocked; missing/invalid recipient; rejected recipient; 6 SMTP error classes; overall timeout; credential redaction |

## 5. Not executed

These tests were **not run**, so they have no result:

| ID | Test | Reason | How to run |
|---|---|---|---|
| ST-01 | Real GitHub read (test repository) | No GitHub token configured in this environment | `npx tsx scripts/m7-sandbox-check.ts --confirm` |
| ST-02 | Real Slack message (sandbox channel) | No Slack webhook | `… --confirm --send` |
| ST-03 | Real Discord message (sandbox channel) | No Discord webhook | `… --confirm --send` |
| ST-04 | Real e-mail (e.g. Mailtrap/Mailpit) | No SMTP account | `… --confirm --send` with `M7_SANDBOX_EMAIL_TO` |
| IT-01 | Senders with M5's real notification worker | The worker doesn't exist on this branch yet; E2E-N01–N09 use a contract driver instead | Re-run the E2E tests against the worker once it's merged |
| IT-02 | Full database round trip (claim/record on PostgreSQL) | Needs the local database harness (`database/tests/run-local-db-tests.sh`) with Docker/PostgreSQL; not available here. Suite 12 of the database tests covers the database side. | Database owner's harness |

Add screenshots of ST-01–ST-04 here once they're run (redact webhook URLs and tokens).

## 6. Issues found during testing

| # | Issue | Found by | Resolution |
|---|---|---|---|
| 1 | The rate-limit wait time was computed with the system clock instead of the client's clock, so the reported `Retry-After` could be wrong. | `GitHubClient > stops calling GitHub after a primary rate limit…` (failed on its first run) | Fixed: `httpRequest` takes the client's clock. The test passes. |
| 2 | Test expectation error: Slack's error code from the response body (`internal_error`) is kept in the message, and the test hadn't expected it. | E2E-N03 (failed on its first run) | Expectation corrected; behaviour unchanged. |
| 3 | `npm ci` failed with `EBADF` on drive E: (about 5 MB free). | Environment | Dependencies installed on C: and linked with a junction. Not a code issue. |
