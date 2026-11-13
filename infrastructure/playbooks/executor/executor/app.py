"""Playbook executor HTTP API, called by n8n workflow 06 (Remediation).

POST /v1/execute  body exactly { action, service_name, playbook_run_id }, HMAC signed.
GET  /health      liveness, no authentication, no details.

A playbook_run_id is executed at most once. A repeat of the same request gets
the stored result (so an n8n retry is safe); a different request for the same
run id is refused.
"""

import logging
import threading
from datetime import datetime, timezone
from typing import Literal
from uuid import UUID

from fastapi import FastAPI, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from executor.actions import ActionError, Actions
from executor.allowlist import SERVICE_PATTERN, Target
from executor.signing import NonceStore, secret_is_valid, verify

EXECUTE_PATH = "/v1/execute"

log = logging.getLogger("executor")


class ExecuteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    action: Literal["restart", "rollback", "scale", "circuit_breaker"]
    service_name: str = Field(pattern=SERVICE_PATTERN.pattern)
    playbook_run_id: UUID


class RunRegistry:
    """Results by playbook_run_id, kept in memory for the life of the process."""

    def __init__(self):
        self._runs: dict[str, dict] = {}
        self._lock = threading.Lock()

    def begin(self, run_id: str, request_key: tuple) -> tuple[str, dict | None]:
        """Return ("new", None), ("done", stored), ("running", None) or ("conflict", None)."""
        with self._lock:
            run = self._runs.get(run_id)
            if run is None:
                self._runs[run_id] = {"key": request_key, "status": 0, "body": None}
                return "new", None
            if run["key"] != request_key:
                return "conflict", None
            if run["body"] is None:
                return "running", None
            return "done", run

    def finish(self, run_id: str, status: int, body: dict) -> None:
        with self._lock:
            self._runs[run_id].update(status=status, body=body)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def reply(status: int, message: str) -> JSONResponse:
    return JSONResponse({"executed": False, "message": message}, status_code=status)


def create_app(secret: str | None, targets: dict[str, Target], actions: Actions) -> FastAPI:
    app = FastAPI(title="playbook-executor", docs_url=None, redoc_url=None, openapi_url=None)
    nonces = NonceStore()
    runs = RunRegistry()

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    @app.post(EXECUTE_PATH)
    async def execute(request: Request):
        if not secret_is_valid(secret):
            return reply(503, "Executor signing secret is not configured.")

        raw = await request.body()
        try:
            body = raw.decode("utf-8")
        except UnicodeDecodeError:
            return reply(400, "Body must be UTF-8 JSON.")

        verdict = verify(secret, request.headers, "POST", EXECUTE_PATH, body, nonces)
        if not verdict.ok:
            log.warning("rejected status=%d reason=%s", verdict.status, verdict.reason)
            return reply(verdict.status, verdict.reason)

        try:
            req = ExecuteRequest.model_validate_json(body)
        except ValidationError as error:
            fields = sorted({".".join(str(p) for p in e["loc"]) or "body" for e in error.errors()})
            log.warning("rejected status=400 invalid fields=%s", fields)
            return reply(400, "Invalid request: " + ", ".join(fields))

        run_id = str(req.playbook_run_id)
        target = targets.get(req.service_name)
        if target is None:
            log.warning("rejected status=403 service=%s run=%s not in allowlist", req.service_name, run_id)
            return reply(403, f"Service {req.service_name} is not in the executor allowlist.")
        if req.action not in target.actions:
            log.warning("rejected status=422 action=%s service=%s run=%s", req.action, req.service_name, run_id)
            return reply(422, f"Action {req.action} is not supported for {req.service_name}.")

        state, stored = runs.begin(run_id, (req.action, req.service_name))
        if state == "done":
            log.info("repeat run=%s returns stored result status=%d", run_id, stored["status"])
            return JSONResponse({**stored["body"], "repeated": True}, status_code=stored["status"])
        if state == "running":
            return reply(409, f"Playbook run {run_id} is already executing.")
        if state == "conflict":
            return reply(409, f"Playbook run {run_id} was already used for a different action or service.")

        result = {"action": req.action, "service_name": req.service_name, "playbook_run_id": run_id, "started_at": now_iso()}
        log.info("execute action=%s service=%s run=%s", req.action, req.service_name, run_id)
        try:
            detail = await run_in_threadpool(actions.run, req.action, target)
            status, result = 200, {**result, "executed": True, "detail": detail}
        except ActionError as error:
            status, result = 500, {**result, "executed": False, "message": str(error)}
        result["finished_at"] = now_iso()
        runs.finish(run_id, status, result)
        log.info("finished action=%s service=%s run=%s status=%d", req.action, req.service_name, run_id, status)
        return JSONResponse({**result, "repeated": False}, status_code=status)

    return app
