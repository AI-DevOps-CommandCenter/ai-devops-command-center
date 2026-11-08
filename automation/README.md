# Automation (n8n workflows + Groq)

Owners: **Vishwa** (01, 05, 06; backend integration, about 40%) and **Tharindu** (00, 02, 03, 04, 07, 08; prompts, about 60%). 09 is shared.

**Safety principle:** the AI only recommends. Nothing an AI writes is ever executed. A fix runs only after a human approves it in the app, and the database checks that approval again before n8n can start the run.

## Workflows

| File | Workflow | Trigger | Status |
|---|---|---|---|
| `00-groq-test.json` | Groq connection test | Manual | ✅ Works (needs the Groq credential and `GROQ_MODEL`) |
| `01-alert-intake.json` | Alertmanager → validate → de-duplicate → 05 | `POST /webhook/alertmanager` | ✅ Works; ⛔ incident creation blocked (BD-1) |
| `02-log-analysis.json` | Loki error/warning analysis | Called by 05 | ✅ Works (Loki label to confirm) |
| `03-metrics-analysis.json` | Prometheus current vs baseline | Called by 05 | ✅ Works (metric names/queries to confirm) |
| `04-deployment-correlation.json` | GitHub commits + Actions runs | Called by 05 | ✅ Works (needs a read-only token) |
| `05-root-cause.json` | Combine evidence → Groq → validate → store | Called by 01 | ✅ Works; ⛔ storage blocked (BD-1/BD-2) |
| `06-remediation.json` | Signed request → backend start → action → complete | `POST /webhook/remediation` | ✅ HMAC, approval and start/complete work; ⛔ execution blocked (no executor; `simulate` for tests) |
| `07-recovery-check.json` | Wait → Prometheus health → verdict → store | Called by 06 | ✅ Works; ⛔ storage blocked (BD-3) |
| `08-postmortem.json` | Groq postmortem draft | Called by 07 | ✅ Works; ⛔ read/store blocked (BD-4) |
| `09-error-handler.json` | Redacted failure summary → Slack/Discord | Error Trigger | ✅ Works (optional webhook URL) |

The blockers (BD-1…BD-6), credentials and open decisions are listed in [`docs/automation-integration-requirements.md`](../docs/automation-integration-requirements.md).

## Quick start (local)

1. **Configure.** Copy `automation/.env.example` to `automation/.env` and fill in your own values. Never commit `.env`. At minimum set:
   - `N8N_ENCRYPTION_KEY`;
   - `GROQ_MODEL`;
   - for workflows 05–07: `BACKEND_BASE_URL` and `MACHINE_SIGNING_SECRET`.
2. **Start n8n:** `cd automation && docker compose up -d`, then open http://localhost:5678 and create the owner account.
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
npm test           # unit tests (Code nodes, schemas, workflow structure, no secrets)
npm run test:hmac  # HMAC interop with the REAL backend middleware (needs backend/node_modules)
npm run test:n8n   # imports everything into a throwaway n8n and runs it against mocks
```

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

## Security checklist

- No API keys in workflows or in git. Keys live in n8n Credentials, which are encrypted with `N8N_ENCRYPTION_KEY`.
- `MACHINE_SIGNING_SECRET` comes from the environment only (≥ 32 characters, same value as the backend).
- No Supabase key of any kind in n8n.
- Workflow 06 refuses unsigned, stale, replayed or unexpected requests, and executes nothing that wasn't approved.
- Error notifications are redacted: no tokens, no stack traces, no input data.
- When exporting from n8n, **never** use "export with credentials" / `--decrypted`.
