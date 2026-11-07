# Backend

## Purpose
The backend provides the API and business logic connecting the mobile application, database, monitoring integrations, AI analysis, and automation workflows.

## Architecture (approved decisions)
- **A1 (hybrid):** Express + Supabase. Every database call uses the **caller's own JWT** through a per-request Supabase client, so Row Level Security applies. Backend checks are an additional layer.
- **D-001:** no runtime service_role (privileged) key. At startup the backend refuses privileged or secret keys.
- **D-002:** authentication and role checks use the user's JWT only.

See `database/DATABASE_DECISION_REGISTER.md` for the full decision status. A2–A7 are still pending.

## Setup
```bash
cd backend
npm install
npm run dev        # watch mode (tsx)
npm start          # run once (tsx)
npm run build      # compile to dist/ (ESM); run with: node dist/server.js
npm run typecheck  # tsc --noEmit
npm test           # Vitest + Supertest (Supabase fully mocked, no network, no .env)
```

## Environment variables
Loaded by `src/config/load-env.ts` from, in priority order:
1. `backend/.env`;
2. the repository-root `.env` (the project's git-ignored env file).

Variables already set in the environment always win, and the first file that defines a variable wins. Set `BACKEND_SKIP_DOTENV=1` to skip file loading (tests, CI, containers). Names only below; never commit values. Empty values (e.g. `PORT=`) count as unset.

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `SUPABASE_URL` | yes | – | Supabase project URL (validated as a URL) |
| `SUPABASE_PUBLISHABLE_KEY` | yes | – | **Publishable** (client) key only. Secret or service-role keys are rejected at startup. |
| `PORT` | no | `3000` | HTTP port |
| `CORS_ORIGINS` | no | empty | Comma-separated browser origins allowed by CORS. Empty means no cross-origin browser access. Native mobile apps are not affected by CORS. |
| `RATE_LIMIT_WINDOW_MS` | no | `900000` | Rate-limit window for `/api` (15 min) |
| `RATE_LIMIT_MAX` | no | `300` | Requests per IP per window on `/api` |
| `TRUST_PROXY` | no | `0` | Number of trusted reverse-proxy hops (`0`–`10`, e.g. `1` behind one proxy). `true` is rejected because it would let clients spoof their IP and bypass rate limiting. |
| `BACKEND_SKIP_DOTENV` | no | – | `1` = don't load any `.env` file |

### CORS notes
- **Native mobile builds** (Android/iOS) send no `Origin` header, so CORS doesn't apply to them.
- **Browser clients** need their exact origin in `CORS_ORIGINS`: scheme, host and port, with no trailing slash, e.g. `http://localhost:5000`. For example, Flutter web, a web dashboard, or Swagger UI from another origin.
- **Flutter web picks a random port** by default. Run it with a fixed port (`flutter run -d chrome --web-port 5000`) and list that origin.
- **Allowed request headers:** `Authorization`, `Content-Type`.

## Structure
| Path | Role |
|---|---|
| `src/server.ts` | Loads `.env` (first import), starts the listener (the only `listen()` call) |
| `src/config/load-env.ts` | `.env` file loading (backend, then repository root) |
| `src/app.ts` | `createApp()`: middleware, routes, error handlers (used by tests) |
| `src/config/env.ts` | Zod validation of environment variables; privileged-key guard |
| `src/config/supabase.ts` | Publishable-key client (JWT verification) and per-request user client |
| `src/middleware/auth.ts` | `authenticateToken` (user JWT); `requireRole(...)` (role read with the user's JWT) |
| `src/middleware/security.ts` | Helmet, restricted CORS, rate limiting |
| `src/middleware/validate.ts` | Zod request-validation middleware |
| `src/middleware/error-handlers.ts` | JSON 404, malformed JSON, generic 500 |
| `src/validation/common.schemas.ts` | Shared Zod schemas (UUID, pagination, ...) |
| `src/routes`, `src/controllers`, `src/services` | API endpoints (unchanged in P1) |
| `tests/` | Vitest + Supertest tests with a mocked Supabase client |

## Error format
All errors use `{ "success": false, "message": "..." }`. Zod validation errors also include `errors: [{ location, path, message }]`.

## P1 backend groundwork (2026-11-07)
**Done:**
- The backend uses the user's JWT only, and refuses to start with a privileged key.
- `requireRole()` added.
- Helmet, restricted CORS and rate limiting.
- Zod environment validation and a `validate()` middleware.
- JSON error handlers.
- `package.json` module type fixed (`"type": "module"`; the duplicate key is removed), and a `build` script added.
- `.env` loading fixed. Before, `dotenv/config` looked only in the current directory (`backend/`), where no `.env` exists. It now also uses the repository-root `.env`.
- Vitest + Supertest with 54 tests. Tests can't reach Supabase: the config module is mocked, `fetch` is blocked, and `.env` loading is disabled.
- `npm audit`: 0 vulnerabilities.

**Behaviour changes:**
- **CORS:** now restricted. It was open to every origin; set `CORS_ORIGINS` for browser clients.
- **Error responses:** unknown routes and malformed JSON now return JSON instead of Express's HTML error pages.
- **Rate limiting:** `/api` returns 429 after `RATE_LIMIT_MAX` requests per window.
- **Authorization header:** the `Bearer` scheme is now matched case-insensitively. An empty token returns "Authentication token is required." instead of "Invalid or expired token."; both are 401.

**Not changed in P1 (pending decisions or later phases):**
- Existing controllers keep their inline role checks and manual validation, so their error messages stay the same. Moving them to `requireRole()` and the Zod schemas is planned with the database-function switch (roadmap P5).
- Audit logging is still best-effort (pending A7).
- Workflow rules are unchanged (pending A3/A4).
- No machine endpoints for n8n yet (pending A5).
- Password reset (A1 port item) is not yet ported.
- Requests under `/api/admin/playbooks` and `/api/admin/integrations` are authenticated twice. That is existing behaviour, not a P1 change: the `/api/admin` router also runs `authenticateToken` for these paths, so they make two token-verification calls. Responses are correct. Fix it when the routes are consolidated (P5).
- The rate limiter keeps its counts in memory, per process. Multiple instances would need a shared store.
