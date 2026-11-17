# Mobile App (Flutter)

The operator app of the DevOps Command Center. It signs in with Supabase and reads and writes everything through the backend API (`backend/`), so the database's row-level security and the two-person approval rule apply to every action.

## Run

```bash
flutter pub get
# Web (used for the demo); the backend must allow the origin in CORS_ORIGINS
flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000
cd build/web && python -m http.server 8080 --bind 127.0.0.1
# or a device/emulator (Android emulator reaches the host at 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`lib/services/supabase_config.dart` holds the Supabase URL and publishable key.

## Main flow

| Step | Screen | Backend |
|---|---|---|
| Sign in | S02 | Supabase Auth, `GET /api/me` (role from `profiles`) |
| Dashboard | S03 | `/api/incidents`, `/api/incidents/:id/recommendation`, `/api/metrics`, `/api/notifications` |
| Incidents, details | S04, S05 | `/api/incidents` |
| Investigation, cause, evidence | S06, S07, S08 | `/api/investigations`, `/api/incidents/:id/recommendation` |
| Request a fix | S17 | `POST /api/playbook-runs` |
| Approve / reject | S18, S31 | `PATCH /api/approvals/:id/decision` |
| Execution, recovery, resolve | S19, S20 | `/api/playbook-runs/:id`, `/api/incidents/:id/recovery-checks`, `PATCH /api/incidents/:id` |
| Postmortem, history | S21, S22 | `/api/postmortems` |

Other screens: logs S09 (`/api/logs`), metrics and services S10–S12 (`/api/metrics`), CI/CD S13–S15 and S24 (`/api/github`), playbooks S16/S38, AI analyses S23, notifications S25/S27, integrations S26, profile S28, search S30, team S37 and audit log S39 (`/api/admin/*`, `/api/audit-logs`).

Admin-only actions (team roles, playbook edits) are hidden for other roles and refused by the database.

## Test

```bash
flutter analyze
flutter test
```
