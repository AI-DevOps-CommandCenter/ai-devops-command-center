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
| 422 | Action not granted for this service in `allowlist.json` |
| 500 | Action failed: `{ executed: false, message }` (stored; a retry needs a new run) |
| 503 | `EXECUTOR_SIGNING_SECRET` missing or shorter than 32 characters |

Per instance, a restart or rollback waits up to 10 s for the stop and up to 60 s for `/health`, and both act on every instance (up to `max_replicas`). Set the n8n HTTP timeout to at least 70 s × instances. Workflow 06 uses `EXECUTOR_URL`, `EXECUTOR_SIGNING_SECRET` and `EXECUTOR_TIMEOUT_MS` (default 240000, enough for 3 instances) with `REMEDIATION_EXECUTION_MODE=executor`. In practice each instance takes a few seconds.

## Environment

| Variable | Required | Default | |
|---|---|---|---|
| `EXECUTOR_SIGNING_SECRET` | yes | none | 32+ characters; every request gets 503 without it |
| `EXECUTOR_ALLOWLIST` | no | `/srv/allowlist.json` in the image | |
| `HEALTH_TIMEOUT_SECONDS` | no | `60` | Wait for `/health` after a restart, rollback or scale-up, per instance |
| `HOST`, `PORT` | no | `0.0.0.0`, `9095` in the image | |
| `LOG_LEVEL` | no | `INFO` | |

## Actions

"Instances" are the main container (`container` in the allowlist) and the replicas a `scale` added (label `dc.executor.replica-of=<service>`). Health and admin calls go to each instance by container name (`http://<container>:<port of base_url>`), never to the shared alias, so the answer comes from the container that was changed.

| Action | What it does |
|---|---|
| `restart` | Docker restart of every instance, one by one; each must answer `/health` 200 |
| `circuit_breaker` | `POST /admin/circuit-breaker {"open": true}` on every instance, 3 attempts each on connection errors and 5xx |
| `rollback` | Recreates every instance from `rollback_image` (the known-good release): stop, rename the old container to `<name>-before-rollback-<time>`, create the new one with the same environment (not the old image's), labels, restart policy, health check, networks and aliases, start, wait for `/health`, then delete the old one. If anything fails, the new container is removed and the old one is renamed back and started. Already on `rollback_image`: nothing changes (`changed: false`) |
| `scale` | Adds replicas `<container>-2` … `<container>-<max_replicas>` from the main container's image, on the same networks with the same alias, so the load balancer (`monitoring/sample-lb`) and Prometheus (DNS discovery) find them. Idempotent; a stopped replica is started again. If a new replica is not healthy, the replicas added by this run are removed. Replicas keep the label `com.docker.compose.service` (for Promtail) but not the compose project label, so `docker compose` does not adopt or delete them |

Nothing in a request can choose a container, an image, a count, a command or a URL: they come from `allowlist.json`:

```json
"sample-app": {
  "container": "dc-sample-app",
  "base_url": "http://sample-app:8000",
  "actions": ["restart", "circuit_breaker", "rollback", "scale"],
  "rollback_image": "dc-sample-app:stable",
  "max_replicas": 3
}
```

`rollback_image` is required for `rollback` (`name:tag`), `max_replicas` (2–5) for `scale`. `monitoring/scripts/release.sh build` builds `dc-sample-app:stable` (v1) and `dc-sample-app:v2-bad` (v2 with 50% errors from startup); `release.sh deploy-bad` deploys the bad release, `release.sh reset` goes back to the compose image and removes the replicas.

## Security notes

- The container mounts the Docker socket, which is root-equivalent on the host. It runs as a non-root user that reaches the socket through group 0. The code only acts on the allowlisted container, its labelled replicas and the allowlisted rollback image; it never pulls images or runs commands.
- Published on `127.0.0.1:9095` only. Nonces and run results are kept in memory: a restart of the executor forgets them (the database run state still allows a run to start once).
- Logs record what was asked, what ran and the result; never headers, signatures or the secret.

## Run and test

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements-dev.txt   # .venv/bin/python on Linux/macOS
.venv/Scripts/python -m pytest
```

In the stack: `monitoring/scripts/create-executor-secret.sh`, then `docker compose up -d executor` in `monitoring/`.
