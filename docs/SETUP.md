# Setup: from `git clone` to a working demo

This guide gets the whole system running on your own computer:
- the monitoring stack, n8n, the backend and the app,
- connected to the team's staging Supabase project.

Nothing secret is stored in git. The Supabase URL and publishable key are in git on purpose: they are public by design (see [section 1a](#1a-why-the-supabase-publishable-key-is-in-git)). You get each secret one of three ways (see [section 1](#1-secrets-who-provides-what)):
- a teammate shares it privately,
- you create it yourself on a website,
- a script generates it on your computer.

Time: about 30–45 minutes the first time.

---

## 1. Secrets: who provides what

| Value | Where it goes | Who provides it |
|---|---|---|
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | `backend/.env` | **Not secret.** Copy `projectUrl` and `anonKey` from `mobile/lib/services/supabase_config.dart` (see [1a](#1a-why-the-supabase-publishable-key-is-in-git)) |
| `AUTOMATION_EMAIL`, `AUTOMATION_PASSWORD` (the Supabase account n8n acts as) | `backend/.env` | **Shared privately** by the team lead |
| Demo account passwords (`demo.admin@demo.local`, `demo.requester@demo.local`) | You type them in the app; optionally `TEST_*_PASSWORD` in `backend/.env` | **Shared privately** by the team lead |
| Groq API key | n8n credential **Groq API**, and `GROQ_API_KEY` in `backend/.env` (developer assistant, S23; without it the assistant answers 503) | **You create it**: free at <https://console.groq.com/keys> |
| GitHub token (fine-grained, read-only) | n8n credential **GitHub API (read-only)**, and `GITHUB_TOKEN` in `backend/.env` | **You create it**: see [step 6](#6-create-your-own-groq-key-and-github-token) |
| `MACHINE_SIGNING_SECRET` (HMAC, n8n ↔ backend) | `backend/.env` + `automation/.env` | **Generated** by `scripts/setup-local.mjs` |
| `EXECUTOR_SIGNING_SECRET` (HMAC, n8n → executor) | `monitoring/.env` + `automation/.env` | **Generated** by `scripts/setup-local.mjs` |
| `N8N_ENCRYPTION_KEY` | `automation/.env` | **Generated** by `scripts/setup-local.mjs` |
| Alertmanager → n8n token | `monitoring/alertmanager/secrets/n8n-token` + n8n credential **Alertmanager Webhook Token** | **Generated** by `scripts/setup-local.mjs` |

Rules:

- **Share privately** means a direct message or a password manager. Never use git, GitHub issues or PR comments, the group chat, or screenshots.
- **Never share the generated secrets.** Each person's are different, and that is fine: they only protect traffic on your own computer.
- **Never use the Supabase `service_role` / secret key.** The backend refuses to start with one. Only the publishable (anon) key is needed.
- **If a secret leaks** (committed, pasted, screenshotted), tell the team lead so it can be rotated. A generated secret you can rotate yourself: delete the line, run the script again and restart the affected containers.

### 1a. Why the Supabase publishable key is in git

The Supabase **publishable key** (`sb_publishable_…`, formerly called the *anon* key) is **public by design**:

- Supabase made it to be shipped inside client apps. Anyone who installs the app can read it from the APK or the web bundle, so keeping it out of git would not hide it.
- It only identifies the project. It gives **no** access of its own: a request with it alone acts as the `anon` role.
- The data is protected by **row-level security (RLS)** in the database, not by the key. Every public table has RLS enabled, and new tables get it automatically (`ensure_rls` event trigger; checked by `database/tests/sql/01_baseline_structure.sql`). The backend sends every database call with the signed-in user's JWT, so each user sees and changes only what the policies allow. Approvals, playbook runs and audit writes go through database functions that check the role again (two-person rule, no self-approval).
- That is why it sits in `mobile/lib/services/supabase_config.dart` and may be copied into `backend/.env` without special care.

What **is** secret, and must never be in git or in the app:

- the **secret / `service_role` key**, which bypasses RLS (the backend refuses to start with one, decision D-001),
- the database password and connection string,
- account passwords (`AUTOMATION_PASSWORD`, demo accounts), API tokens and the generated HMAC secrets.

If the publishable key is rotated in the Supabase dashboard, update `supabase_config.dart` and every `backend/.env`.

## 2. Prerequisites

- Git
- Docker Desktop (running)
- Node.js 20 or newer
- Python 3
- Flutter 3.x (`flutter doctor` without errors for *web*)

You do **not** need the Supabase CLI or a database of your own. The staging project already has every migration and the demo accounts.

## 3. Clone and install

```bash
git clone https://github.com/AI-DevOps-CommandCenter/ai-devops-command-center.git
cd ai-devops-command-center
git checkout dev

cd backend && npm install && cd ..
cd automation && npm install && cd ..
cd mobile && flutter pub get && cd ..
```

## 4. Generate the local secrets

From the repository root:

```bash
node scripts/setup-local.mjs
```

The script does the following:

- creates `backend/.env`, `automation/.env` and `monitoring/.env` from their `.env.example` files,
- adds the tested Prometheus/Loki settings from `monitoring/n8n-integration.env` to `automation/.env`,
- generates the four local secrets from the table above, using the same value in every file that needs it,
- lists what you still have to fill in.

It never prints a secret and never overwrites a value that is already set. You can run it again at any time. `node scripts/setup-local.mjs --check` only reports and changes nothing.

## 5. Fill in the shared values

Open `backend/.env`. Copy the Supabase URL and publishable key from `mobile/lib/services/supabase_config.dart`, and fill in the passwords the team lead sent you:

```ini
SUPABASE_URL=...                 # projectUrl in supabase_config.dart
SUPABASE_PUBLISHABLE_KEY=...     # anonKey in supabase_config.dart (sb_publishable_…)
AUTOMATION_EMAIL=automation@demo.local
AUTOMATION_PASSWORD=...
# optional, lets scripts/check-project.mjs log in:
TEST_USER_EMAIL=demo.admin@demo.local
TEST_USER_PASSWORD=...
TEST_REQUESTER_EMAIL=demo.requester@demo.local
TEST_REQUESTER_PASSWORD=...
```

In `automation/.env`, switch remediation on for the demo. Without this, workflow 06 refuses every fix:

```ini
REMEDIATION_EXECUTION_MODE=executor
```

The executor only runs the allow-listed actions on `sample-app` (`infrastructure/playbooks/executor/allowlist.json`).

## 6. Create your own Groq key and GitHub token

**Groq**:
1. Sign in at <https://console.groq.com/keys> and create a key.
2. Keep it in a password manager. It goes into n8n in step 8, not into a `.env` file.

**GitHub**:
1. Go to GitHub → *Settings → Developer settings → Fine-grained personal access tokens → Generate new token*.
2. Fill in the token:
   - Resource owner: **AI-DevOps-CommandCenter**. An org owner may have to approve the token.
   - Repository access: **Only select repositories** → `ai-devops-command-center`.
   - Permissions (all **Read-only**): Metadata, Contents, Pull requests, Actions.
   - Expiration: a short one (for example 30 days).
3. Put it in `backend/.env` as `GITHUB_TOKEN=...`. You will also paste it into n8n in step 8.

The GitHub token is optional. Without it, only the CI/CD screens and the deployment-correlation step stay empty.

## 7. Start the monitoring stack

```bash
cd monitoring
docker compose up -d --build
cd ..
```

This starts Prometheus (:9090), Alertmanager (:9093), Loki (:3100), Promtail, `sample-app`, its load balancer `sample-lb`, the load generator and the playbook executor (:9095). All ports are bound to 127.0.0.1 only.

Then build the two sample-app releases that the **rollback** playbook needs:

```bash
bash monitoring/scripts/release.sh build    # dc-sample-app:stable (v1) and dc-sample-app:v2-bad
```

Without `dc-sample-app:stable`, a rollback fails safely with "Rollback image … does not exist" and changes nothing.

## 8. Start n8n and import the workflows

```bash
cd automation
docker compose -p ccdemo up -d
cd ..
```

Always use `-p ccdemo`. The n8n data (owner account, credentials, workflows) lives in the `ccdemo_n8n_data` volume.

1. Open <http://localhost:5678> and create the n8n owner account. It is local to your computer, so use any email and password.
2. **Credentials** → *Create* → **Header Auth**, three times. The names must match exactly:

   | Credential name | Header name | Value |
   |---|---|---|
   | `Groq API` | `Authorization` | `Bearer <your Groq key>` |
   | `GitHub API (read-only)` | `Authorization` | `Bearer <your GitHub token>` |
   | `Alertmanager Webhook Token` | `Authorization` | `Bearer <content of monitoring/alertmanager/secrets/n8n-token>` |

   To view the token: `cat monitoring/alertmanager/secrets/n8n-token` (PowerShell: `Get-Content monitoring/alertmanager/secrets/n8n-token`).

3. Import the workflows. Use the CLI so the sub-workflow links are kept:

   ```bash
   docker exec -it n8n n8n import:workflow --separate --input=/import/workflows
   ```

4. Open workflows 00, 01, 04, 05 and 08. On every node with a ⚠ credential warning, select the matching credential and save.
5. Run **00 – Groq Connection Test**. The result must be `PASS`.
6. **Publish** 01 and 06 (webhooks), 02, 03, 04, 05, 07 and 08 (sub-workflows), and 09 (error handler). Publish 09 first: 06 cannot be published until 09 is.

## 9. Start the backend

```bash
cd backend
npm run dev        # http://localhost:3000
```

Leave it running in its own terminal. <http://localhost:3000/> should answer 200.

## 10. Build and serve the app

```bash
cd mobile
flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000
cd build/web
python -m http.server 8080 --bind 127.0.0.1
```

Open <http://127.0.0.1:8080> and log in as `demo.admin@demo.local`. If you change the port, add the new origin to `CORS_ORIGINS` in `backend/.env`.

## 11. Check everything

In a new terminal, from the repository root:

```bash
node scripts/setup-local.mjs --check   # local secrets and .env files
node scripts/check-project.mjs         # 31 read-only checks of the running system
```

`check-project.mjs` must end with **ALL GOOD: 31/31 checks passed**. Every failing line says what to do.

## 12. Run the demo

```bash
bash monitoring/scripts/fault.sh errors 0.5    # sample-app now fails half its requests
```

1. After about 3 minutes, a new incident with an AI root-cause analysis appears in the app.
2. Log in as **`demo.requester@demo.local`**, open the incident and request the **restart** playbook.
3. Log in as **`demo.admin@demo.local`** and approve it. The requester can never approve their own request.
4. Watch the run:
   - the executor restarts `sample-app`,
   - workflow 07 checks recovery (about 1–3 minutes),
   - workflow 08 drafts the postmortem.
5. Mark the incident resolved and open the postmortem.

**Rollback and scale demos:**
- Rollback: `bash monitoring/scripts/release.sh deploy-bad` deploys v2, which fails half its requests from startup. A restart does not help; the **rollback** playbook recreates the container from `dc-sample-app:stable`.
- Scale: the **scale** playbook adds 2 replicas (3 instances in total) behind `sample-lb`. Use it with `fault.sh latency 0.5`.
- Check with `bash monitoring/scripts/release.sh status`.

Afterwards:

```bash
bash monitoring/scripts/release.sh reset      # compose image again, replicas removed
bash monitoring/scripts/fault.sh off
bash monitoring/scripts/fault.sh breaker closed   # only if the circuit-breaker playbook was used
```

All teammates share the staging Supabase project. Incidents created by your local stack are visible to everyone, so clean up after testing.

## 13. Stopping and restarting

```bash
cd monitoring && docker compose stop && cd ..
cd automation && docker compose -p ccdemo stop && cd ..
```

The containers use `restart: unless-stopped`, so they come back by themselves after a Docker Desktop restart. If they were stopped, start them again with `docker compose up -d` (monitoring) and `docker compose -p ccdemo up -d` (automation). The backend and the web server must be restarted by hand.

After changing a `.env` file, recreate the affected containers:
- `docker compose up -d` in `monitoring/`, or
- `docker compose -p ccdemo up -d` in `automation/`.

A plain `restart` does not reload `.env`.

## 14. Troubleshooting

| Symptom | Fix |
|---|---|
| `check-project.mjs`: containers "not running" | Start Docker Desktop, then see step 13. |
| n8n logs `Mismatching encryption keys` | The `ccdemo_n8n_data` volume was created with a different `N8N_ENCRYPTION_KEY`. Put the old key back. If you have nothing to keep, delete the volume with `docker compose -p ccdemo down -v` (**this deletes your n8n owner account, credentials and workflows**) and repeat step 8. |
| Executor answers 503 | `EXECUTOR_SIGNING_SECRET` is missing in `monitoring/.env` or differs from `automation/.env`. Run `node scripts/setup-local.mjs --check`, then recreate both stacks. |
| Backend `/api/machine/*` answers 503 | `MACHINE_SIGNING_SECRET`, `AUTOMATION_EMAIL` or `AUTOMATION_PASSWORD` is missing in `backend/.env`. |
| No incident after the fault | Alertmanager → n8n: the credential **Alertmanager Webhook Token** must be `Bearer ` + the exact content of `monitoring/alertmanager/secrets/n8n-token`, and workflow 01 must be published. |
| Backend exits with a "privileged key" message | You used the Supabase secret/service_role key. Use the publishable key. |
| App shows network/CORS errors | The backend is not running on :3000, or the web origin is missing in `CORS_ORIGINS`. |
| Workflow 00 fails | Wrong Groq key, or `GROQ_MODEL` was retired. Pick a current model at <https://console.groq.com/docs/models>, set it in `automation/.env` and recreate n8n. |
