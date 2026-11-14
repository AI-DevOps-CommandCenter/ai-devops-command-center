# Tharindu – Workflow Ownership (about 60%)

> **Disclosure (please read):** the initial workflow JSON files in this folder were **generated with Claude Code** (an AI assistant) on 8 Nov 2026, from the team's agreed contracts. **Tharindu did not originally write these files.**
> Tharindu's contribution is to **understand, integrate, improve, test and document** them with the real services, as listed in "Your contribution" below. Report it honestly to the supervisor.

## Your workflows

| File | Purpose | How it helps the incident flow |
|---|---|---|
| `00-groq-test.json` | Checks that the Groq key and model work | First thing to run; proves the AI connection |
| `02-log-analysis.json` | Loki: error/warning lines of the service around the incident | Gives 05 the **log evidence** |
| `03-metrics-analysis.json` | Prometheus: CPU, memory, error rate, latency now vs 30 min before | Gives 05 the **metric evidence** |
| `04-deployment-correlation.json` | GitHub: commits and Actions runs shortly before the incident | Gives 05 **possible causes** (recent changes) |
| `07-recovery-check.json` | After a fix: waits, checks `up` and the error rate, repeats up to N times | Decides **recovered / not recovered / unable to verify** |
| `08-postmortem.json` | Groq writes a blameless postmortem draft | The **report** at the end of the incident |

Contracts you must keep (so Vishwa's 05 and 06 still work):
- 02/03/04 return `automation/schemas/investigation-output.schema.json`;
- 07 returns `{ incident_id, playbook_run_id, status, db_status, checks_performed, evidence, ok, stored, … }`.

Node-by-node explanation: `docs/automation-node-reference.md`.

## 1. Import into n8n 2.40.5
1. Start n8n: `cd automation && cp .env.example .env` (fill in your own values), then `docker compose up -d`, then open http://localhost:5678.
2. Import with the **CLI** (keeps the workflow ids that 05 and 06 use):
   ```bash
   docker exec -it n8n n8n import:workflow --separate --input=/import/workflows
   ```
   (`/import/workflows` is `automation/workflows/`, mounted read-only.) Importing a single file in the editor also works, but you must then re-select the sub-workflow in any *Execute Workflow* node.
3. Publish 02, 03, 04, 07 and 08. n8n 2.x calls the published version of a sub-workflow.

## 2. Credentials (never commit or share them)
n8n → Credentials → **Header Auth**:
- **Groq API**: Name `Authorization`, Value `Bearer <your Groq key>`.
- **GitHub API (read-only)**: Name `Authorization`, Value `Bearer <fine-grained token>`. Give it read-only *Contents* and *Actions* on one repository only.

Settings go in `automation/.env` (git-ignored):
- `GROQ_MODEL`;
- `LOKI_URL`, `LOKI_SERVICE_LABEL`;
- `PROMETHEUS_URL`, `PROM_SERVICE_LABEL`, `PROM_QUERY_ERROR_RATE`, `PROM_THRESHOLD_ERROR_RATE`;
- `GITHUB_OWNER`, `GITHUB_REPO`.

Never export workflows "with credentials".

## 3. Test with mock data first
```bash
cd automation
npm test           # unit tests (no n8n needed)
npm run test:n8n   # imports all workflows into a throwaway n8n 2.40.5 and runs them against mocks
```
Sample data: `automation/test-data/` (alert, Loki logs, Prometheus values, GitHub commits/runs). In the editor you can also use **pin data** with these files.

## 4. Real integration tests (your main job)
| Test | Steps | Evidence to keep |
|---|---|---|
| Groq | Run 00 with your key → PASS; then with a wrong key → `auth` | Screenshots of both executions |
| Loki | With Keshan, find the label that names the service; set `LOKI_SERVICE_LABEL`; break the sample app; run 02 | Execution output with real lines |
| Prometheus | With Keshan, write the error-rate / latency / request-rate PromQL and thresholds; run 03 normal vs broken | Before/after values |
| GitHub | Create the read-only token; run 04 on the real repo; then with a bad token → `auth` | Output and screenshot |
| Recovery | Break → fix the sample app; run 07 → `recovered`; leave it broken → `not_recovered` | Both outputs |
| Postmortem | Run 08 with the real recovery result; check that nothing is invented | Draft + your review notes |

Record the results in `docs/automation-testing-guide.md` (manual tests M1–M5, M9).

## 5. Your contribution (what to deliver and commit from YOUR account)
- [ ] Explain every node of your 6 workflows (be ready for viva questions)
- [ ] Real LogQL label and patterns for 02 (changes in `automation/src/nodes/02-log-analysis/`)
- [ ] Real PromQL queries and thresholds for 03 and 07 (in `.env.example` and the docs)
- [ ] Improved Groq prompts after testing with real incidents (`automation/prompts/`)
- [ ] Extra unit tests for every change (`automation/tests/unit.test.mjs`)
- [ ] Bugs found in real testing, and their fixes
- [ ] Test evidence (screenshots and results) for the report
- [ ] Optional: developer assistant (Gantt 48)

**How to change a workflow:**
1. Edit the code in `automation/src/nodes/<workflow>/`.
2. Run `npm run build` and then `npm test`.
3. Commit on **`feature/n8n-ai-investigation`** and open a PR into `feature/n8n-incident-workflow`. Vishwa reviews it.
