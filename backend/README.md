# AI-Powered Mobile DevOps Command Center - Backend

## 1. Overview

The backend provides REST APIs and business logic connecting the Flutter mobile application with Supabase authentication and database services.

It manages incidents, investigations, approvals, playbook executions, remediation records, audit logs, postmortems, and dashboard information.

### Architecture (approved decisions)

- **A1 (hybrid):** Express + Supabase. Every database call uses the **caller's own JWT** through a per-request Supabase client, so PostgreSQL **Row Level Security (RLS)** applies to every query. Backend checks (authentication, roles, input validation) are an additional layer on top of RLS.
- **D-001:** no runtime service_role (privileged) key. At startup the backend refuses privileged or secret keys; only the publishable key is accepted.
- **D-002:** authentication and role checks use the user's JWT only (`authenticateToken`, `requireRole`), never a privileged key.
- **A2–A7** (security boundary, approval workflow, n8n identity, notifications, audit logging) are approved and implemented in the database migrations `supabase/migrations/…000400`–`…000800`. The backend uses the secure database functions for every approval and playbook-run write, and never writes the audit log itself (section 10, "Workflow endpoints").

See `database/DATABASE_DECISION_REGISTER.md`, `database/DATABASE_TEAM_HANDOVER.md` and `database/API_AND_INTEGRATION_CONTRACTS.md` for details.

## 2. Technology Stack

- Node.js
- Express.js
- TypeScript (ES modules)
- Supabase (PostgreSQL and Authentication)
- REST API
- Zod (environment and request validation)
- Helmet, CORS allow-list, express-rate-limit (security)
- Vitest + Supertest (tests)
- npm

## 3. Project Structure

```text
backend/
├── src/
│   ├── config/
│   │   ├── env.ts            # Zod validation of environment variables; privileged-key guard
│   │   ├── load-env.ts       # .env file loading (backend/.env, then repository-root .env)
│   │   └── supabase.ts       # publishable-key client (JWT verification) and per-request user client
│   ├── controllers/
│   ├── middleware/
│   │   ├── auth.ts           # authenticateToken (user JWT), requireRole(...)
│   │   ├── security.ts       # Helmet, restricted CORS, rate limiting
│   │   ├── validate.ts       # Zod request-validation middleware
│   │   ├── error-handlers.ts # JSON 404, malformed JSON, generic 500
│   │   └── machine-auth.ts   # signed n8n requests (HMAC + replay protection)
│   ├── lib/db-errors.ts      # database error -> HTTP status mapping (DC401/403/404/409/422, ...)
│   ├── routes/
│   ├── services/
│   ├── validation/           # shared Zod schemas (UUID, pagination, ...)
│   ├── app.ts                # createApp(): middleware, routes, error handlers (used by tests)
│   └── server.ts             # loads .env (first import) and starts the listener
├── tests/                    # Vitest + Supertest tests with a mocked Supabase client
├── dist/                     # production build output (generated)
├── .env                      # local only, never committed
├── package.json
├── package-lock.json
├── tsconfig.json
├── vitest.config.ts
└── README.md
```

## 4. Prerequisites

- Node.js
- npm
- Git
- A Supabase project

## 5. Installation

Navigate to the backend directory:

```bash
cd backend
```

Install dependencies:

```bash
npm install
```

## 6. Environment Configuration

Create a `.env` file inside the backend directory (or use the repository-root `.env`).

Add the following variables:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_PUBLISHABLE_KEY=your_supabase_publishable_key
PORT=3000
```

Use the actual values from the team's Supabase project.

`src/config/load-env.ts` loads variables from, in priority order:

1. `backend/.env`;
2. the repository-root `.env`.

Variables already set in the environment always win, and the first file that defines a variable wins. The paths are resolved from the file's own location, so this works the same for `npm run dev` (`src/`) and `npm start` (`dist/`). Empty values (e.g. `PORT=`) count as unset.

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `SUPABASE_URL` | yes | – | Supabase project URL (validated as a URL) |
| `SUPABASE_PUBLISHABLE_KEY` | yes | – | **Publishable** (client) key only. Secret or service-role keys are rejected at startup (D-001). |
| `PORT` | no | `3000` | HTTP port |
| `CORS_ORIGINS` | no | empty | Comma-separated browser origins allowed by CORS. Empty means no cross-origin browser access. Native mobile apps are not affected by CORS. |
| `RATE_LIMIT_WINDOW_MS` | no | `900000` | Rate-limit window for `/api` (15 min) |
| `RATE_LIMIT_MAX` | no | `300` | Requests per IP per window on `/api` |
| `TRUST_PROXY` | no | `0` | Number of trusted reverse-proxy hops (`0`–`10`, e.g. `1` behind one proxy). `true` is rejected because it would let clients spoof their IP and bypass rate limiting. |
| `BACKEND_SKIP_DOTENV` | no | – | `1` = don't load any `.env` file (tests, CI, containers that inject variables directly) |
| `MACHINE_SIGNING_SECRET` | for n8n | – | Shared HMAC secret for n8n requests (at least 32 characters). Same value in n8n's credential store. |
| `AUTOMATION_EMAIL` | for n8n | – | Sign-in email of the dedicated automation user (profile role `automation`, set by the database owner). |
| `AUTOMATION_PASSWORD` | for n8n | – | Its password. Backend secret store only, never in n8n or Flutter. |

The three n8n variables enable `/api/machine/*`. All three must be set together, otherwise startup fails with the name of the missing variable. Without them the machine endpoints answer 503. How the automation user is provisioned and rotated is still open (decision A5-Q2).

### CORS notes

- **Native mobile builds** (Android/iOS) send no `Origin` header, so CORS doesn't apply to them.
- **Browser clients** need their exact origin in `CORS_ORIGINS`: scheme, host and port, with no trailing slash, e.g. `http://localhost:5000`. For example, Flutter web, a web dashboard, or Swagger UI from another origin.
- **Flutter web picks a random port** by default. Run it with a fixed port (`flutter run -d chrome --web-port 5000`) and list that origin.
- **Allowed request headers:** `Authorization`, `Content-Type`.

**Security:** Never commit `.env` files or expose the Supabase secret/service role key in the Flutter application or Git repository.

## 7. Running the Backend

### Development

```bash
npm run dev
```

Runs `src/server.ts` with `tsx` in watch mode.

### Production Build

```bash
npm run build
```

### Production Start

```bash
npm start
```

The production build generates JavaScript files in `dist/`. `npm start` runs `node dist/server.js`, so run `npm run build` first.

## 8. API Server

Default local base URL:

```text
http://localhost:3000
```

Health endpoint:

```http
GET /
```

Expected response:

```json
{
  "message": "AI-Powered Mobile DevOps Command Center API is running!"
}
```

## 9. Authentication

The backend uses Supabase Authentication.

Protected API requests require the user's Supabase access token:

```http
Authorization: Bearer YOUR_SUPABASE_ACCESS_TOKEN
```

The backend validates the token with Supabase Auth (publishable key only) and creates a **user-scoped Supabase client** that carries the same JWT, so every database call is subject to that user's RLS policies. The `Bearer` scheme is matched case-insensitively; a missing or empty token returns 401.

`requireRole(...)` restricts a route to given application roles (`user`, `operator`, `admin`). The role is read from `profiles` with the user's own JWT (D-002).

### Get Authenticated User

```http
GET /api/me
```

Requires a valid access token.

## 10. API Route Groups

| Route | Purpose |
|---|---|
| `/api/me` | Authenticated user details |
| `/api/incidents` | Incident management |
| `/api/dashboard` | Dashboard statistics |
| `/api/investigations` | Incident investigation records |
| `/api/approvals` | Remediation approval management |
| `/api/audit-logs` | Audit log access |
| `/api/playbook-runs` | Playbook execution requests and decisions |
| `/api/postmortems` | Incident postmortems |
| `/api/remediation-executions` | Legacy remediation records (read-only) |
| `/api/admin` | User administration |
| `/api/admin/playbooks` | Playbook administration |
| `/api/admin/integrations` | Integration administration |
| `/api/machine` | n8n machine endpoints (signed requests, automation identity) |

Protected routes require authentication. Individual endpoints enforce authorization and database Row Level Security policies.

### Workflow endpoints (database functions)

Approval and playbook-run writes call the secure database functions with the caller's JWT (decisions A2/A3/A4). The database checks roles and separation of duties, prevents duplicate execution, and writes the audit entry in the same transaction.

| Endpoint | Who | Database function |
|---|---|---|
| `POST /api/playbook-runs` `{ incident_id, playbook_id, request_payload?, idempotency_key? }` | any signed-in user (own incidents), operator, admin | `request_playbook_run`: creates the run **and** its pending approval. Every run needs a human approval (A4). Same `idempotency_key` = same run (200 instead of 201). |
| `POST /api/approvals` `{ incident_id, playbook_id, ... }` | same | same function. **`playbook_id` is now required**: an approval always belongs to one run (A3). |
| `PATCH /api/approvals/:id/decision` `{ status: approved\|rejected, comments? }` | **admin or operator, never on their own request** | `decide_approval` |
| `PATCH /api/playbook-runs/:id/decision` `{ status, comments? }` | same | `decide_approval` on the run's linked approval |
| `POST /api/approvals/:id/cancel` `{ reason? }` | the requester | `cancel_approval` (cancels the run too) |
| `POST /api/playbook-runs/:id/cancel` `{ reason? }` | requester while pending; admin/operator with a reason once approved or running | `cancel_playbook_run` |
| `POST /api/playbook-runs/:id/complete` `{ status: success\|failed, reason, result_payload? }` | admin/operator, **manual override**, reason of 5+ characters (A3-Q3) | `complete_playbook_run` |
| `POST /api/machine/playbook-runs/:id/start` `{ n8n_execution_id, workflow_name? }` | **n8n only** (signed request) | `start_playbook_run` as the automation identity |
| `POST /api/machine/playbook-runs/:id/complete` `{ n8n_execution_id, status, result? }` | **n8n only** (signed request) | `complete_playbook_run` with the same execution id |
| `POST`/`PATCH /api/remediation-executions` | – | **410 Gone**: legacy and read-only. Use playbook runs. |

**Error statuses:** the database's own message is returned with `403` (role, or own request), `404` (not found or not visible), `409` (already decided, duplicate active run, wrong state, duplicate execution) and `400` (invalid input). Other database errors give a generic message.

**Machine request signing** (`src/middleware/machine-auth.ts`): headers `X-DC-Timestamp`, `X-DC-Nonce`, `X-DC-Signature: sha256=<hex HMAC-SHA256(secret, timestamp.nonce.METHOD.path.rawBody)>`. The path is the full request path, e.g. `/api/machine/playbook-runs/<id>/start`. Requests more than 5 minutes off and reused nonces are rejected.

Refer to the team's API documentation (`database/API_AND_INTEGRATION_CONTRACTS.md`) for endpoint methods, request bodies, response formats, and examples.

### Security middleware

Applied to every request in `src/app.ts`:

- **Helmet** security headers; `X-Powered-By` disabled.
- **CORS allow-list** from `CORS_ORIGINS` (previously open to every origin).
- **Rate limiting** on `/api`: HTTP 429 after `RATE_LIMIT_MAX` requests per IP per `RATE_LIMIT_WINDOW_MS`. Counts are kept in memory per process; multiple instances would need a shared store.
- **Startup validation** of all environment variables (Zod); privileged keys are refused.

### Error handling

All errors use the same JSON shape:

```json
{ "success": false, "message": "..." }
```

- Unknown routes return 404 `Route not found.`
- Malformed JSON bodies return 400 `Malformed JSON request body.`; oversized bodies return 413.
- Unexpected errors return 500 `Internal server error.` (details are logged, not returned).
- Zod request-validation errors also include `errors: [{ location, path, message }]`.

## 11. TypeScript Validation and Tests

Check for TypeScript errors:

```bash
npx tsc --noEmit        # or: npm run typecheck
```

Run the tests:

```bash
npm test                # Vitest + Supertest, single run
npm run test:watch      # watch mode
```

The tests never reach Supabase: the Supabase config module is mocked, `fetch` is blocked, and `.env` loading is disabled (`BACKEND_SKIP_DOTENV=1`). They cover:
- the app setup, authentication, environment validation, request validation, rate limiting, and the no-privileged-key guard (D-001);
- signed n8n requests and the machine endpoints;
- the approval and playbook-run database functions, including unauthorized operations and database error mapping;
- remediation being read-only.

A contract guard (`tests/rpc-contract.test.ts`) fails if any code writes `approvals`, `playbook_runs`, `remediation_executions` or `audit_logs` directly, or calls a database function with parameter names that differ from `supabase/migrations`.

## 12. Development Notes

- Do not commit `.env` or other secrets.
- Never expose the Supabase service role key to the mobile application.
- Follow the team's Git feature-branch and pull-request workflow.
- Coordinate database schema and API contract changes with the relevant team members.

### Integration status

- **Database-function switch: done.** Approval and playbook-run writes use the database functions. Remediation executions are read-only (410 on write), and the backend writes no audit entries: the database functions and triggers write exactly one entry per action (database test suite 14).
- **n8n machine endpoints: implemented, not yet enabled.** They need the automation user and the three variables from section 6 (decision A5-Q2: who provisions and rotates them).
- Existing controllers keep their inline role checks and manual validation; moving them to `requireRole()` and the Zod schemas is a later clean-up.
- Requests under `/api/admin/playbooks` and `/api/admin/integrations` are authenticated twice (the `/api/admin` router also runs `authenticateToken`). Responses are correct; fix it when the routes are consolidated.
- Password reset is not yet ported.
