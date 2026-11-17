# Automation (n8n workflows + Groq)

Owners: **Vishwa** (01, 05, 06; backend integration, about 40%) and **Tharindu** (00, 02, 03, 04, 07, 08; prompts, about 60%). 09 is shared.

**Safety principle:** the AI only recommends. Nothing an AI writes is ever executed. A fix runs only after a human approves it in the app, and the database checks that approval again before n8n can start the run.

## Workflows

| File | Workflow | Trigger | Status |
|---|---|---|---|
| `00-groq-test.json` | Groq connection test | Manual | ✅ Works (needs the Groq credential and `GROQ_MODEL`) |
| `01-alert-intake.json` | Alertmanager → validate → de-duplicate (pending/confirmed) → create incident → 05 → soft failures to 09 | `POST /webhook/alertmanager` | ✅ Works. Creates or reuses the incident by alert fingerprint through `POST /api/machine/incidents` (BD-1) |
| `02-log-analysis.json` | Loki error/warning analysis | Called by 05 | ✅ Works (label `service`, D-MON-1) |
| `03-metrics-analysis.json` | Prometheus current vs baseline | Called by 05 | ✅ Works (queries from `monitoring/n8n-integration.env`) |
| `04-deployment-correlation.json` | GitHub commits + Actions runs | Called by 05 | ✅ Works with mocks; needs a valid read-only token for real data |
| `05-root-cause.json` | Combine evidence → Groq → validate → store | Called by 01 | ✅ Works. Stores the analysis through the backend (BD-2) |
| `06-remediation.json` | Signed request → backend start → action → complete (retry-safe) → 07 → soft failures to 09 | `POST /webhook/remediation` | ✅ Works. Called by the backend after an approval (BD-5); real execution through the playbook executor (`REMEDIATION_EXECUTION_MODE=executor`); completion retried safely (N-1). Known issue KI-1 (nonce store) |
| `07-recovery-check.json` | Wait → Prometheus health → verdict → store | Called by 06 | ✅ Works. Stores through `POST /api/machine/recovery-checks` (BD-3) |
| `08-postmortem.json` | Read incident context → Groq postmortem draft → store | Called by 07 | ✅ Works. Reads `GET /api/machine/incidents/:id/context` and stores through `POST /api/machine/incidents/:id/postmortem` (BD-4) |
| `09-error-handler.json` | Redacted failure summary → Slack/Discord | Error Trigger + called by 01/06 for soft failures | ✅ Works (optional webhook URL) |

**How this was verified:**
- Automated: mocks (`npm run test:n8n`) and the real backend code (`npm run test:interop`).
- Live, 17 Nov 2026: a full real-alert run with real Prometheus, Alertmanager, Loki, Groq, the playbook executor and the staging Supabase project. The path was fault → alert → 01 → 02/03/04 → 05 → approval in the app → backend → 06 → executor → 07 → 08 postmortem.

The original blockers (BD-1…BD-6), the credentials and the decisions are listed in [`docs/automation-integration-requirements.md`](../docs/automation-integration-requirements.md).

## Quick start (local)

For the whole system (monitoring, n8n, backend, app), follow [`docs/SETUP.md`](../docs/SETUP.md). The steps below cover n8n only.

1. **Configure.** Run `node scripts/setup-local.mjs` from the repository root. It creates `automation/.env` from `.env.example` and generates `N8N_ENCRYPTION_KEY`, `MACHINE_SIGNING_SECRET` and `EXECUTOR_SIGNING_SECRET`. Never commit `.env`. Then check:
   - `GROQ_MODEL` (a current model from <https://console.groq.com/docs/models>);
   - `BACKEND_BASE_URL` (the backend, normally `http://host.docker.internal:3000`);
   - `REMEDIATION_EXECUTION_MODE=executor` for real fixes (default `disabled`: 06 refuses every fix).
2. **Start n8n:** `cd automation && docker compose -p ccdemo up -d`, then open http://localhost:5678 and create the owner account. Always use `-p ccdemo`: the n8n data lives in the `ccdemo_n8n_data` volume. The port is published on `127.0.0.1` only (see *Network and HTTPS*).
3. **Create the credentials** (n8n → Credentials → *Header Auth*). The names must match exactly:
   - **Groq API**: Name `Authorization`, Value `Bearer <your Groq key>`.
   - **GitHub API (read-only)**: Name `Authorization`, Value `Bearer <fine-grained token>`, with read-only Contents and Actions on one repository.
   - **Alertmanager Webhook Token**: Name `Authorization`, Value `Bearer <random token>`.
4. **Import the workflows.** Use the CLI so the sub-workflow ids are kept:
   ```bash
   docker exec -it n8n n8n import:workflow --separate --input=/import/workflows
   ```
   If you import through the editor instead (*Import from file*), re-select the sub-workflow in every *Execute Workflow* node and the error workflow in each workflow's settings.
5. **Attach the credentials.** Open 00, 01, 04, 05 and 08, click each node with a ⚠ credential warning and select the credential.
6. **Run 00 – Groq Connection Test.** The result must be `PASS`.
7. **Publish** 01 and 06 (webhooks), and 02–05, 07, 08 (sub-workflows). n8n 2.x calls the published version of a sub-workflow. Webhooks become reachable some seconds after n8n starts.

## Develop and test

```bash
cd automation
npm run build      # regenerate workflows/*.json from src/
npm test             # unit tests (Code nodes, retry/dedupe/soft-failure logic, workflow structure, no secrets)
npm run test:hmac    # HMAC interop with the REAL backend middleware (needs backend/node_modules)
npm run test:interop # HMAC interop + workflow 07's request against the REAL /api/machine/recovery-checks route
npm run test:n8n     # imports everything into a throwaway n8n and runs it against mocks
```

`test:n8n` checks the error notifications with a local HTTPS receiver. It creates a throwaway self-signed certificate with `openssl` (Git for Windows includes it; set `OPENSSL_BIN` if it is elsewhere), which only the test n8n process trusts. Without openssl, those checks are reported as SKIP. The test never posts to a real webhook, even if `ERROR_NOTIFY_WEBHOOK_URL` is set in your shell.

Details: [`docs/automation-testing-guide.md`](../docs/automation-testing-guide.md). Node-by-node reference: [`docs/automation-node-reference.md`](../docs/automation-node-reference.md). Architecture: [`docs/automation-implementation-guide.md`](../docs/automation-implementation-guide.md).

## Folder guide

| Folder | Contents |
|---|---|
| `workflows/` | Generated n8n exports (import these; don't hand-edit) |
| `src/nodes/` | Code node scripts, one file per Code node |
| `src/lib/` | Shared helpers: HMAC signing/verification, HTTP classification, AI validation |
| `prompts/` | Groq system prompts (RCA, postmortem; the original investigation prompt is kept) |
| `schemas/` | JSON schemas: investigation output, RCA, postmortem, original AI output |
| `test-data/` | Sample Alertmanager, Loki, Prometheus and GitHub payloads |
| `tests/` | Unit tests, HMAC interop, n8n integration test and mocks |
| `github-gitlab/`, `docs/` | Notes |

## AI output rules

- `recommended_action` must be exactly one of `restart`, `rollback`, `scale`, `circuit_breaker`, or `null`. These are the database's playbook action types; anything else is rejected.
- `severity`: `low`, `medium`, `high` or `critical`. `confidence`: 0–1.
- The RCA separates `confirmed_findings` (shown by the data) from `possible_causes` (not proven), and always has `requires_human_review: true`.
- If no source found any evidence, the AI is not called at all.

## Network and HTTPS

- **Default: keep `N8N_BIND_ADDRESS=127.0.0.1`.** `docker-compose.yml` publishes n8n on `${N8N_BIND_ADDRESS:-127.0.0.1}:${N8N_PORT:-5678}`, so only your own computer can open the editor and the webhooks. The container still reaches the backend, Loki and Prometheus on your computer through `host.docker.internal` (unchanged).
- **Remote access** (staging/production, or another machine that must reach n8n, for example Alertmanager on a different host or in a container on Linux, where `host.docker.internal` is not the loopback address): use an **HTTPS reverse proxy with appropriate access controls**, and keep the port on `127.0.0.1`.
- **Never expose n8n directly on `0.0.0.0` over plain HTTP.** The editor and the webhooks would then be reachable from the network without TLS.
- **HTTPS is required by contract B.3, but it is NOT configured in this repository.** The compose file is for local development and runs n8n on plain HTTP (`N8N_PROTOCOL=http`). To deploy:
  - keep `N8N_BIND_ADDRESS=127.0.0.1`;
  - put a TLS-terminating reverse proxy in front, on the same host (for example Caddy, nginx or Traefik);
  - restrict who can reach it, for example an IP allow-list for the backend and Alertmanager, and extra authentication (or no external route at all) for the n8n editor;
  - set `N8N_HOST`, `N8N_PROTOCOL=https` and `N8N_WEBHOOK_URL=https://<host>/`;
  - point the backend (`/webhook/remediation`) and Alertmanager at the `https://` URL.
- Workflow 09 only sends notifications to `https://` webhook URLs.

## Security checklist

- No API keys in workflows or in git. Keys live in n8n Credentials, which are encrypted with `N8N_ENCRYPTION_KEY`.
- `MACHINE_SIGNING_SECRET` comes from the environment only (≥ 32 characters, same value as the backend).
- No Supabase key of any kind in n8n.
- Workflow 06 refuses unsigned, stale, replayed or unexpected requests, and executes nothing that wasn't approved.
- A signed request is never re-sent: the completion retry (06) signs every attempt again with a new nonce.
- Error notifications are redacted: no tokens, no stack traces, no input data. Soft failures (failed completion, unconfirmed start, AI unavailable, result not stored) are reported too, one message per kind per execution.
- The n8n port is published on `127.0.0.1` by default (`N8N_BIND_ADDRESS`).
- **Decision D-N8N-1 (decided 17 Nov 2026):** `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` stays, as a recorded, time-limited exception to rule A5. It lets every Code node read `MACHINE_SIGNING_SECRET`, so it is only allowed under these conditions:
  - one trusted n8n owner account, and no other workflow editors;
  - only the variables listed in `docker-compose.yml` are passed to the container;
  - API keys stay in n8n Credentials;
  - n8n is published on `127.0.0.1` only.

  Before any shared or hosted deployment, revisit option B (move signing out of `$env`). Details: `database/DATABASE_DECISION_REGISTER.md` (D-010) and `docs/automation-decision-proposals.md`.
- When exporting from n8n, **never** use "export with credentials" / `--decrypted`.
