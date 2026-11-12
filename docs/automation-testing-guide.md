# Automation – Testing Guide

There are three automated test levels. None of them touches real Groq, Loki, Prometheus, GitHub, the backend or Supabase.

| Level | Command (from `automation/`) | What it proves | Needs |
|---|---|---|---|
| Unit | `npm test` | Code node logic: validation, HMAC verify, replay, RCA/postmortem schema, de-duplication, recovery verdicts, redaction. Generated JSON: valid links, known node types/versions, error workflow set, no secrets, up to date, no AI → execution path. | Node 20+ |
| HMAC interop | `npm run test:hmac` | The n8n signing code and the **real** backend middleware (`backend/src/middleware/machine-auth.ts`) accept each other's signatures, in both directions | `backend/node_modules` (tsx) |
| Backend route interop | `npm run test:interop` | HMAC interop, plus: workflow 07's real request is accepted by the **real** `POST /api/machine/recovery-checks` route (only the database is faked), and 07 handles 201/400/401/404/409/500 correctly; plus the BD-5 remediation webhook interop (next row) | `backend/node_modules` (tsx) |
| BD-5 remediation webhook interop | `npm run test:interop:remediation` (also part of `test:interop`) | A request signed by the backend's **real** `buildSignedHeaders()` is checked by workflow 06's **real** "Verify signature and payload" node: valid → accepted; wrong bytes / path / secret, forged signature, any missing header, expired timestamp, bad nonce → 401; extra field → 400; replayed nonce → 409; missing secret → 503; `disabled` mode → 503 (verifier output + workflow routing) | `backend/node_modules` (tsx) |
| n8n integration | `npm run test:n8n` | All 10 workflows import into **n8n 2.40.5** and run end to end against mock services (`tests/integration/mock-services.mjs`), including completion retries, error notifications through workflow 09, and a second n8n start with `REMEDIATION_EXECUTION_MODE=disabled` (BD-5) | n8n CLI 2.40.5 (`npm i -g n8n@2.40.5`), free ports 4597, 4598, 4599, 5690, 5691, `openssl` for the notification checks (otherwise SKIP) |
| Replay protection (opt-in) | `npm run test:n8n:replay` | Duplicate and concurrent remediation requests against a live n8n 2.40.5 and the mock backend (scenarios S1–S5). **One check fails on purpose** (known issue KI-1, see below). Not part of `npm test` or `test:n8n`. | Same as n8n integration; free ports 4698, 4699, 5790, 5791 |

The integration test uses its own temporary n8n folder (never `~/.n8n`). It imports test credentials with fake values, publishes the workflows, starts n8n and calls the webhooks.

## Results (12 Nov 2026, Windows 11, Node 24.12, n8n 2.40.5)

| Suite | Result |
|---|---|
| Unit (`npm test`) | **84 / 84 passed** (7 files) |
| HMAC interop with the real backend middleware | **PASS** in both directions (10 Nov) |
| Recovery-check interop with the real backend route | **PASS** (10 Nov) |
| BD-5 remediation webhook interop (`npm run test:interop:remediation`) | **12 / 12 passed** |
| n8n integration (`npm run test:n8n`) | **91 / 91 checks passed**, 0 skipped (86 checks of 10 Nov + n8n restart in `disabled` mode + 4 BD-5 checks) |
| Replay protection (`npm run test:n8n:replay`) | **19 / 20**: the expected failure of known issue KI-1 (S5), reproduced in every run |
| Backend (`cd backend && npx vitest run`) | **153 / 153 passed**; `npx tsc --noEmit` clean (10 Nov, not re-run) |

(8 Nov 2026: unit 18/18, integration 61/61, before N-1, N-2, N-3 and BD-3. 10 Nov: integration 86/86, before the BD-5 disabled-mode checks.)

All of these use mocks or fakes. **No production or real-service end-to-end test has been run** (see *Manual tests* below).

Integration checks per workflow. All ran **against mocks**, so they are simulated, not tests against real services:

| Workflow | Scenarios that passed |
|---|---|
| Import | Credentials and all 10 workflows import into n8n 2.40.5 |
| 00 Groq | valid → PASS; invalid key → `auth`; 429 → `rate_limited`; slow → `timeout`; non-JSON → `invalid_response`; unknown model → `not_found` |
| 01 Intake | missing token → 403; valid → 202 with 1 new; repeat → duplicate; empty payload → 400; resolved → 202, no incident |
| 02 Logs | errors → `evidence_found` (secrets redacted); empty → `no_evidence`; Loki down → `unavailable`; bad query → `query_rejected`; bad input → `invalid_input` |
| 03 Metrics | abnormal → cpu and error_rate flagged; normal → `no_evidence`; no data → `unavailable`; down → `unavailable` |
| 04 Deploys | recent deploy found 15 min before; none → `no_evidence`; bad token → `unavailable` with `auth` |
| 05 RCA | all evidence → `analysis_ready`; no incident → not stored (BD-1); store call signed and accepted, route missing → `not_implemented` (BD-2); partial → `partial_evidence`; no evidence → Groq **not** called; all down → `sources_unavailable`; bad JSON / unsafe action → `invalid_ai_response` |
| 06 Remediation | approved → 202, start + complete (simulated); replay while running → 409 and run executed once; reused nonce later → 409 from n8n; not approved → 409; bad HMAC / stale time → 401; unknown action / extra fields → 400; action mismatch → 409 and run completed as failed |
| 07 Recovery | recovered → `healthy`, **stored** via BD-3 with `recovery_check_id`, body matches the contract; not recovered after 2 checks (stored as `unhealthy`); no metrics → `unable_to_verify`; unknown service → `unable_to_verify` without waiting; unknown incident (404) → `not_found` + soft failure; backend 500 → soft failure |
| 08 Postmortem | complete context → `draft_ready`, not stored (BD-4); no context → no Groq call; Groq 429 → `ai_unavailable` |
| N-1 completion retry (06) | 503, 503, 200 → 3 attempts, completed once, recovery checked; every attempt a new nonce and valid signature, same body; timeout ×3 → exactly 3 attempts, run not reported complete, no recovery check; connection dropped → retried; 500 → retried; 400 / 401 → 1 attempt; response lost after the database completed → retry gets 409, run counted as completed, no false alert |
| N-2 notifications (01, 06 → 09) | successful and expected-refusal runs → no notification; completion failure, HTTP 400 / 401 completion, start timeout, recovery check not stored, AI unavailable → one redacted notification each (no secret, token, signature or webhook URL in the body). Workflow 09 runs inside the live n8n and posts to a local HTTPS test receiver. |
| BD-5 disabled mode (06) | n8n restarted with `REMEDIATION_EXECUTION_MODE=disabled`; a fully valid signed request for an **approved** run → **HTTP 503**, `accepted: false`, message says execution is not available and the run was not started; **0** backend calls (no `/start`); run stays `approved` (not running, failed or completed) |

**Replay protection scenarios** (`npm run test:n8n:replay`, mock backend, 12 Nov):

| Scenario | HTTP responses | `/start` calls reaching the backend / successful | Run | Rejected by |
|---|---|---|---|---|
| S1 exact replay (same timestamp, nonce, signature, body) after the first execution ended | 202, then 409 `Replayed request.` | 1 / 1 | `success`, 1 completion | n8n nonce store, no backend call |
| S2 exact replay while the first execution is still running | 202, 409 | 2 / 1 | `success`, 1 completion | backend run state |
| S3 two identical requests at the same time | 202 + 409 | 2 / 1 | `success`, 1 completion | backend run state |
| S4 five identical requests at the same time | one 202, four 409 | 5 / 1 | `success`, 1 completion | backend run state (n8n: 0) |
| S5 two **different** valid requests at the same time, then each replayed | 202, 202, then 409, 409 | the replay whose nonce was lost reaches `/start` again (refused) | both `success`, 1 completion each | one by n8n, one by backend run state → **check FAILS (KI-1)** |

No run was started or completed twice. The duplicate protection seen here comes from the **mock** backend's run-state check; the real database row lock (`start_playbook_run`, `SELECT … FOR UPDATE`) was not exercised.

**Bugs the tests found and that are now fixed:**
- `URLSearchParams` does not exist in the n8n 2.x Code-node sandbox. Workflows 02, 03, 04 and 07 used it; a unit test now prevents it.
- `ETIMEDOUT` was not classified as retryable in workflow 09.
- 07 returned the postmortem output instead of its own result.

**Covered in a live local n8n since 10–12 Nov** (previously unit-tested only):
- workflow 09's **soft-failure** entry point ("When called with a soft failure"), called by 01 and 06, including the HTTPS notification (N-2 checks);
- `REMEDIATION_EXECUTION_MODE=disabled` (BD-5 checks).

**Not covered by automated tests:**
- workflow 09's **crash** entry point ("On workflow error") inside a running n8n, and whether n8n runs it when a sub-workflow crashes (logic unit-tested only);
- concurrent replay protection in n8n alone (known issue KI-1);
- the real backend calling n8n after an approval (BD-5 backend trigger not implemented);
- every real external service, the real database and Supabase.

## Manual tests with real services (still to do)

Simulated runs do not prove the real services work. Run these after setup:

| # | Test | How | Expected |
|---|---|---|---|
| M1 | Groq, valid key | Run workflow 00 | `PASS` |
| M2 | Groq, invalid key | Change the credential value, run 00 | `FAIL`, `failure: auth` |
| M3 | Loki labels | Break the sample app, run 02 via 05 (or pin data) | `evidence_found` with real lines |
| M4 | Prometheus queries | Same incident, check 03 | cpu / error_rate flagged |
| M5 | GitHub token | Run 04 against the real repository | commits/runs listed; with a bad token → `auth` |
| M6 | Alertmanager → 01 | Fire a test alert (`amtool alert add …` or break the app) | 202, and 05 runs |
| M7 | Backend start/complete | Approved run; backend calls `/webhook/remediation` (needs the BD-5 backend trigger), mode `simulate` | Run `running` → `success`, audit rows written by the database |
| M7b | Disabled mode, real backend | Same as M7 with `REMEDIATION_EXECUTION_MODE=disabled` | 503; run stays `approved` in the database |
| M8 | Not approved | Call 06 for a pending run | 409, nothing executed |
| M9 | Recovery | After M7 with real metrics | `recovered` or `not_recovered` with values |
| M10 | Error handler | Set `ERROR_NOTIFY_WEBHOOK_URL`; make 03 fail | One redacted message in Slack/Discord |

## Test data

`automation/test-data/` holds realistic payloads. Use them in n8n with *pin data*, or with the mock server:
- `sample-alert.json`: Alertmanager v4;
- `sample-logs.json`: Loki `query_range`;
- `sample-metrics.json`: Prometheus values;
- `sample-deployment.json`: GitHub commits and runs.

Sample incident: `checkout-api`, `HighErrorRate`, 2026-11-08 10:00 UTC.
