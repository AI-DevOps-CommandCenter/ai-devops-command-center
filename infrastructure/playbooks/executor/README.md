# Playbook executor

Runs the fixed remediation actions for n8n workflow 06. See `docs/monitoring-implementation-plan.md`, step 7.

## Contract

`POST /v1/execute`, `Content-Type: application/json`, body exactly:

```json
{ "action": "restart" | "rollback" | "scale" | "circuit_breaker", "service_name": "sample-app", "playbook_run_id": "<uuid>" }
```

Signed with the project HMAC scheme (same as `automation/src/lib/hmac.js` and `backend/src/middleware/machine-auth.ts`):

- `X-DC-Timestamp` (unix seconds, within ±300 s), `X-DC-Nonce` (16 to 200 chars `[A-Za-z0-9_-]`, new for every request), `X-DC-Signature: sha256=<hex>`
- `HMAC-SHA256(EXECUTOR_SIGNING_SECRET, timestamp + "." + nonce + ".POST./v1/execute." + rawBody)`
- From n8n: `signedBackendRequest({ MACHINE_SIGNING_SECRET: <executor secret>, BACKEND_BASE_URL: "http://host.docker.internal:9095" }, "POST", "/v1/execute", body)` produces a correct request (tested from the n8n container, 13 Nov 2026).

| HTTP | When |
|---|---|
| 200 | Action ran: `{ executed: true, action, service_name, playbook_run_id, started_at, finished_at, detail, repeated: false }` |
| 200 / 500 with `repeated: true` | Same `playbook_run_id`, action and service as before: the stored result, nothing runs again |
| 400 | Invalid JSON, missing or extra field, bad uuid, unknown action |
| 401 | Missing headers, bad timestamp, outside ±300 s, bad nonce format, wrong signature |
| 403 | `service_name` not in `allowlist.json` |
| 409 | Nonce already used, run still executing, or run id already used for another action or service |
| 422 | Action not granted for this service (today: `rollback`, `scale`) |
| 500 | Action failed: `{ executed: false, message }` (stored; a retry needs a new run) |
| 503 | `EXECUTOR_SIGNING_SECRET` missing or shorter than 32 characters |

Set the n8n HTTP timeout to at least 90 s: a restart waits up to 10 s for the stop and up to 60 s for `/health`.

## Actions

| Action | What it does | Status |
|---|---|---|
| `restart` | Docker restart of the allowlisted container, then waits until `<base_url>/health` is 200 | done |
| `circuit_breaker` | `POST <base_url>/admin/circuit-breaker {"open": true}`, 3 attempts on connection errors and 5xx | done |
| `rollback`, `scale` | Not implemented (decision D-MON-6) | 422 |

Nothing in a request can choose a container, a command or a URL: they come from `allowlist.json`.

## Security notes

- The container mounts the Docker socket, which is root-equivalent on the host. It runs as a non-root user that reaches the socket through group 0, and the code only gets and restarts the allowlisted container.
- Published on `127.0.0.1:9095` only. Nonces and run results are kept in memory: a restart of the executor forgets them (the database run state still allows a run to start once).
- Logs record what was asked, what ran and the result; never headers, signatures or the secret.

## Run and test

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements-dev.txt   # .venv/bin/python on Linux/macOS
.venv/Scripts/python -m pytest
```

In the stack: `monitoring/scripts/create-executor-secret.sh`, then `docker compose up -d executor` in `monitoring/`.
