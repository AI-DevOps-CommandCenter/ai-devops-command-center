# Vishwa – Workflow Ownership (about 40%)

> **Disclosure:** the initial workflow JSON files in this folder were generated with **Claude Code** (AI assistant) on 8 Nov 2026, from the team's agreed contracts. They are **copies** of `automation/workflows/`. Vishwa's contribution is the architecture and contracts, reviewing and integrating these workflows, the backend work listed below, and the end-to-end testing.

## Workflows

| File | Purpose |
|---|---|
| `01-alert-intake.json` | Receives Alertmanager alerts (`POST /webhook/alertmanager`, token-protected), validates them, drops duplicates (fingerprint + startsAt), answers 202, and starts **05** for every new alert |
| `05-root-cause.json` | Runs Tharindu's **02, 03, 04** in parallel, combines the evidence, asks Groq for a root cause only if evidence exists, validates the answer (`schemas/rca-output.schema.json`) and sends it to the backend (signed) |
| `06-remediation.json` | Receives the signed "run approved" request from the backend, verifies the HMAC signature, time and nonce, asks the backend to **start** the run (the database re-checks the approval), runs one fixed action branch, reports **complete**, then starts Tharindu's **07** |
| `09-error-handler.json` (shared) | When any workflow fails: builds a short, secret-free summary and optionally posts it to Slack/Discord |

## How they fit in

```
Alertmanager → 01 → 05 → (Tharindu: 02 logs, 03 metrics, 04 deploys) → Groq → backend
App approval → backend → 06 → backend start/complete → (Tharindu: 07 recovery → 08 postmortem)
Any failure → 09
```

Contracts shared with Tharindu:
- `automation/schemas/investigation-output.schema.json` (02/03/04 → 05);
- the recovery result format (07 → 08);
- `docs/automation-implementation-guide.md` §6.

## Status (12 Nov 2026)
Details: `docs/automation-integration-requirements.md` (contracts, known issues, handoff in §7) and `docs/automation-testing-guide.md` (test results).

**Done (n8n side):**
- [x] **BD-3**: backend route `POST /api/machine/recovery-checks` (`aa671cb`) and the 07 integration (`60e9683`); tested with Vitest, the route interop test and the live n8n suite (mocks)
- [x] **BD-5 n8n side**: 06 verifies the signed webhook (HMAC, ±5 min, nonce), answers 202/400/401/404/409/502/503 (contract in §2a), `disabled` mode → 503 without starting the run; interop with the backend's real `buildSignedHeaders()` (`npm run test:interop:remediation`, 12/12) and live checks (`npm run test:n8n`, 91/91)
- [x] **N-1** retry-safe completion, **N-2** soft-failure notifications through 09, **N-3** alert de-dupe confirmation (`60e9683`), **N-5** n8n on `127.0.0.1` (`b99ee0f`)
- [x] 09 soft-failure path and `disabled` mode tested in a live local n8n (not only unit tests)

**Known issue:** **KI-1**: 06's replay nonces live in workflow static data and can be lost under concurrent executions; the database run state prevents a second start (seen with a mock backend only). Not fixed; strict failing check kept in `npm run test:n8n:replay`. Proposal D-N8N-6 in `docs/automation-decision-proposals.md`.

**Waiting on others (see the handoff table, §7):**
- [ ] **BD-5 backend trigger**: Vinuka: call `POST <n8n>/webhook/remediation` after an approval (`buildSignedHeaders`, new nonce per attempt)
- [ ] **BD-6**: backend sets `request_payload.service_name`
- [ ] **Real execution**: Keshan's playbook executor (06 has `disabled`/`simulate` only)
- [ ] **KI-1**: backend + database team agree an atomic shared nonce store
- [ ] **BD-1**: incident creation (contract + migration + route); then replace "Create incident (backend) – BLOCKED" in 01
- [ ] **BD-2**: AI-analysis storage contract and route (05 needs no change)
- [ ] **BD-4**: read incident data and save postmortems (with Vinuka; workflow 08 is Tharindu's)
- [ ] **D-N8N-1**: env access for the HMAC secret, decided by the register owner (proposal in `docs/automation-decision-proposals.md`)

## Testing responsibilities
- [x] `cd automation && npm test` (84/84), `npm run test:interop` (incl. remediation 12/12), `npm run test:n8n` (91/91): all against mocks
- [ ] Manual tests M6–M8 and M10 in `docs/automation-testing-guide.md` (real Alertmanager, real backend start/complete once the BD-5 trigger exists, a run that is not approved, real notification webhook)
- [ ] The full end-to-end demo with Tharindu (Gantt task 41): **no production or real-service end-to-end test has passed yet**
- [ ] Review Tharindu's Pull Requests

## Note on files
These are copies. The source of truth is `automation/src/` + `automation/scripts/build-workflows.mjs`, which generate `automation/workflows/`. After a rebuild, copy the files here again.
