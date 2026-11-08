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

## Remaining responsibilities (backend integration)
See `docs/automation-integration-requirements.md`.

- [ ] **BD-5**: the backend calls `POST <n8n>/webhook/remediation` after an approval (`buildSignedHeaders`)
- [ ] **BD-3**: `POST /api/machine/recovery-checks` → `record_recovery_check`
- [ ] **BD-2**: `POST /api/machine/investigations/:id/analysis` → `record_ai_analysis`, plus investigation creation
- [ ] **BD-1**: create an incident from an alert (add it to the contract first; idempotent on the fingerprint)
- [ ] **BD-4**: read incident data and save postmortems (with Vinuka)
- [ ] Replace the `… – BLOCKED` nodes in 01 when BD-1 exists
- [ ] Decision D-N8N-1 (env access for the HMAC secret), recorded in the decision register

## Testing responsibilities
- [ ] `cd automation && npm test`, `npm run test:hmac`, `npm run test:n8n` stay green
- [ ] Manual tests M6–M8 in `docs/automation-testing-guide.md` (real Alertmanager, real backend start/complete, a run that is not approved)
- [ ] The full end-to-end demo with Tharindu (Gantt task 41)
- [ ] Review Tharindu's Pull Requests

## Note on files
These are copies. The source of truth is `automation/src/` + `automation/scripts/build-workflows.mjs`, which generate `automation/workflows/`. After a rebuild, copy the files here again.
