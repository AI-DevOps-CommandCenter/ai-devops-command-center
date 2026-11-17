# AI-Powered Mobile DevOps Command Center

A mobile command center for production incidents. Prometheus detects a problem, n8n investigates it (logs, metrics, recent deployments) and Groq AI proposes a probable cause and a reviewed fix. A person approves the fix in the Flutter app, the executor runs it, n8n checks that the service recovered and the AI drafts a postmortem.

**Group 33 · University project · Supervisor: Mr. Diluka Wijesinghe**

---

## 1. What it does (end to end)

```
 sample-app ──metrics/logs──▶ Prometheus / Loki
                                  │ HighErrorRate
                                  ▼
                            Alertmanager ──▶ n8n 01 Alert intake ──▶ backend: create incident (deduplicated by fingerprint)
                                                   │
                                                   ▼
                       n8n 02 logs · 03 metrics · 04 deployments (GitHub)
                                                   ▼
                       n8n 05 root cause (Groq) ──▶ backend: store AI analysis
                                                   ▼
   Flutter app: incident → AI cause + evidence → operator requests a playbook
                                                   ▼
   second person (approver) approves  ──▶ backend BD-5 ──signed──▶ n8n 06 remediation
                                                   ▼
                                  executor (signed, allow-listed actions) changes the service
                                                   ▼
                       n8n 07 recovery check (Prometheus) ──▶ n8n 08 postmortem (Groq)
                                                   ▼
             app: recovery result → "Mark incident resolved" → postmortem → history
```

Verified on 17 Nov 2026 with a real alert: fault injected → alert → incident → AI analysis from live data → circuit-breaker playbook requested and approved → executor opened the breaker → recovery check *healthy* → postmortem stored → incident resolved.

## 2. Components

| Folder | What | Technology |
|---|---|---|
| `mobile/` | Mobile app (also runs as Flutter web) | Flutter / Dart |
| `backend/` | REST API, every DB call with the caller's JWT (RLS), signed machine endpoints for n8n, read APIs for metrics, logs and GitHub | Node.js, Express 5, TypeScript, Zod |
| `supabase/`, `database/` | Schema, RLS, approval workflow, audit triggers, migrations, rollback scripts and SQL test suites | Supabase / PostgreSQL |
| `automation/` | n8n workflows 00–09, shared Code-node helpers, HMAC signing, generator and tests | n8n 2.40.5, Groq |
| `monitoring/` | Prometheus, Alertmanager, Loki, Promtail, sample-app with fault injection, load generator, playbook executor | Docker Compose, Python |
| `scripts/` | `check-project.mjs` – read-only health check of the whole stack | Node.js |
| `docs/` | Automation guides, integration contracts, GitHub/notification (M7) docs | Markdown |

### App screens backed by real data

Dashboard (S03), incidents (S04–S08), logs (S09), metrics and services (S10–S12), CI/CD (S13–S15, S24), playbooks (S16, S38), remediation flow (S17–S21, S31), history (S22), AI analyses (S23), notifications (S25, S27), integrations (S26), profile (S28), search (S30), team (S37), audit log (S39).

## 3. Security model

- **Row Level Security everywhere.** The backend never uses a service_role key; it refuses one at startup. Each request uses the caller's JWT, so the database decides what a user may read or change.
- **Two-person rule.** The requester of a remediation can never approve it (enforced in the database).
- **Signed machine traffic.** n8n ↔ backend and n8n → executor use HMAC signatures with timestamps and nonces; unsigned requests get 401.
- **Allow-lists.** The executor only runs known actions on known services; GitHub access is read-only and limited to `GITHUB_REPOSITORIES`; service names are validated before they reach PromQL/LogQL.
- **Audit trail.** Database triggers write every incident, approval, run and postmortem change to `audit_logs`.
- **Secrets** live only in git-ignored `.env` files and n8n credentials.

## 4. Running it locally

Prerequisites: Docker Desktop, Node.js 20+, Flutter 3.x, Python 3, a Supabase project with the migrations from `supabase/migrations` applied.

```bash
# 1. Monitoring stack (Prometheus, Alertmanager, Loki, sample-app, executor)
cd monitoring && cp .env.example .env      # set EXECUTOR_SIGNING_SECRET
docker compose up -d

# 2. n8n (workflows are in automation/workflows; import and publish 01–08)
cd ../automation && cp .env.example .env   # N8N_ENCRYPTION_KEY, MACHINE_SIGNING_SECRET, EXECUTOR_SIGNING_SECRET, PROM_*/LOKI_*
docker compose -p ccdemo up -d
# create the Groq, GitHub (read-only) and Alertmanager credentials in the n8n UI

# 3. Backend
cd ../backend && cp .env.example .env      # Supabase, signing secret, automation user, URLs
npm install && npm run dev                 # http://localhost:3000

# 4. App (web build served on :8080)
cd ../mobile
flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000
cd build/web && python -m http.server 8080 --bind 127.0.0.1
```

Check everything at once:

```bash
node scripts/check-project.mjs      # 31 read-only checks, prints ALL GOOD or what failed
```

### Running the full scenario

```bash
bash monitoring/scripts/fault.sh errors 0.5     # make sample-app fail half its requests
# ~3 min later: incident + AI analysis appear in the app
# operator (demo.requester) requests a playbook; approver (demo.admin) approves it
bash monitoring/scripts/fault.sh off            # afterwards
bash monitoring/scripts/fault.sh breaker closed # if the circuit-breaker playbook was used
```

Demo accounts (staging Supabase): `demo.requester@demo.local` (operator) and `demo.admin@demo.local` (admin). Passwords are not stored in the repository.

## 5. Tests

| Suite | Command | Result (17 Nov 2026) |
|---|---|---|
| Backend (unit, contract, integration) | `cd backend && npx vitest run` | 359 passed |
| Automation (workflow build, Code nodes, HMAC interop) | `cd automation && npm test` | 93 passed |
| Database (migrations, RLS, approval workflow, rollback guards) | `TEST_PG_PORT=45432 bash database/tests/run-local-db-tests.sh` | 355 assertions passed |
| Mobile | `cd mobile && flutter analyze && flutter test` | no issues, 18 passed |
| Executor | `pytest` in `monitoring/` | 32 passed (16 Nov) |
| Whole stack | `node scripts/check-project.mjs` | 31/31 checks |

## 6. Known limitations and future work

- Runs on one machine (Docker + localhost); the monitored service is a purpose-built sample-app so faults can be injected safely.
- Push notifications (FCM) are queued in the database but no Firebase sender is implemented; approvers are notified in-app.
- Per-user notification preferences are not stored.
- The n8n replay store can lose a nonce under concurrent requests (KI-1); the backend's run state prevents double execution. Fix: consume nonces through the database.
- The GitHub screens need a read-only `GITHUB_TOKEN` in `backend/.env`.
- Remediation webhook delivery is retried in memory (no outbox table).

## 7. Team

| Member | Area |
|---|---|
| Vishwa | Integration lead, n8n workflows 01/05/06/09, backend–automation contracts, database migrations, end-to-end testing |
| Vinuka | Backend API and RPC integration, remediation webhook (BD-5/BD-6) |
| Gayathri | Mobile UI |
| Himasha | Mobile API integration and authentication |
| Keshan | Monitoring stack and playbook executor |
| Tharindu | n8n workflows 00/02/03/04/07/08, demo seed data |
| Thilina | GitHub integration and email/Slack/Discord notification senders |

## License

No license has been selected.
