import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseModuleFactory, TEST_TOKEN } from "./helpers/mock-supabase-module.js";
import { createMockUserClient, callsFor } from "./helpers/supabase-mock.js";
import { testConfig } from "./helpers/config.js";
import {
  buildSignedHeaders,
  createMemoryNonceStore
} from "../src/middleware/machine-auth.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

// Synthetic test secret (not a real credential).
const SECRET = "test-only-machine-secret-0123456789abcdef";
const NOW = new Date("2026-11-08T12:00:00Z");
const RUN_ID = "55555555-5555-4555-8555-555555555551";
const START_PATH = `/api/machine/playbook-runs/${RUN_ID}/start`;
const COMPLETE_PATH = `/api/machine/playbook-runs/${RUN_ID}/complete`;

let nonceCounter = 0;
function nonce() {
  nonceCounter += 1;
  return `machine-test-nonce-${String(nonceCounter).padStart(6, "0")}`;
}

function buildApp(results: Parameters<typeof createMockUserClient>[0] = {}, failSignIn = false) {
  const mock = createMockUserClient(results);
  const invalidate = vi.fn();
  const app = createApp(testConfig(), {
    machine: {
      signingSecret: SECRET,
      automation: {
        get: () =>
          failSignIn
            ? Promise.reject(new Error("sign-in failed"))
            : Promise.resolve(mock.client as never),
        invalidate
      },
      nonceStore: createMemoryNonceStore(() => NOW),
      now: () => NOW
    }
  });
  return { app, calls: mock.calls, invalidate };
}

function signed(path: string, body: object, nonceValue = nonce()) {
  const raw = JSON.stringify(body);
  return {
    raw,
    headers: buildSignedHeaders(SECRET, { method: "POST", path, body: raw, nonce: nonceValue, now: NOW })
  };
}

describe("n8n machine endpoints (A5)", () => {
  it("answer 503 when not configured", async () => {
    const app = createApp(testConfig(), { machine: null });

    const res = await request(app).post(START_PATH).send({ n8n_execution_id: "exec-1" });

    expect(res.status).toBe(503);
    expect(res.body.message).toBe("Machine endpoints are not configured.");
  });

  it("reject unsigned requests, even with a valid user JWT", async () => {
    const { app, calls } = buildApp();

    const res = await request(app)
      .post(START_PATH)
      .set("Authorization", `Bearer ${TEST_TOKEN}`)
      .send({ n8n_execution_id: "exec-1" });

    expect(res.status).toBe(401);
    expect(calls).toEqual([]);
  });

  it("start -> start_playbook_run as the automation identity", async () => {
    const started = {
      run_id: RUN_ID,
      status: "running",
      automation_run_id: "55555555-5555-4555-8555-555555555552",
      incident_id: "55555555-5555-4555-8555-555555555553",
      action_type: "restart",
      request_payload: { target: "checkout-api" }
    };
    const { app, calls } = buildApp({ "rpc:start_playbook_run": { data: started } });
    const { raw, headers } = signed(START_PATH, { n8n_execution_id: "exec-1", workflow_name: "remediation" });

    const res = await request(app).post(START_PATH).set(headers).type("json").send(raw);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, message: "Playbook run started.", data: started });
    expect(callsFor(calls, "rpc:start_playbook_run", "rpc")[0]?.args[0]).toEqual({
      p_run_id: RUN_ID,
      p_n8n_execution_id: "exec-1",
      p_workflow_name: "remediation"
    });
  });

  it("a replayed signed request is rejected (409) and the run is started once", async () => {
    const { app, calls } = buildApp({ "rpc:start_playbook_run": { data: { run_id: RUN_ID } } });
    const { raw, headers } = signed(START_PATH, { n8n_execution_id: "exec-2" });

    const first = await request(app).post(START_PATH).set(headers).type("json").send(raw);
    const replay = await request(app).post(START_PATH).set(headers).type("json").send(raw);

    expect(first.status).toBe(200);
    expect(replay.status).toBe(409);
    expect(callsFor(calls, "rpc:start_playbook_run", "rpc")).toHaveLength(1);
  });

  it("starting a run that is not approved is 409 (A4: approval first)", async () => {
    const { app } = buildApp({
      "rpc:start_playbook_run": { error: { code: "DC409", message: "The run is pending_approval, not approved." } }
    });
    const { raw, headers } = signed(START_PATH, { n8n_execution_id: "exec-3" });

    const res = await request(app).post(START_PATH).set(headers).type("json").send(raw);

    expect(res.status).toBe(409);
    expect(res.body.message).toBe("The run is pending_approval, not approved.");
  });

  it("a reused n8n execution id is 409 (duplicate execution, 23505)", async () => {
    const { app } = buildApp({
      "rpc:start_playbook_run": { error: { code: "23505", message: "duplicate key value" } }
    });
    const { raw, headers } = signed(START_PATH, { n8n_execution_id: "exec-1" });

    const res = await request(app).post(START_PATH).set(headers).type("json").send(raw);

    expect(res.status).toBe(409);
    expect(res.body.message).toBe("Duplicate request.");
  });

  it("complete -> complete_playbook_run with the execution id", async () => {
    const { app, calls } = buildApp({
      "rpc:complete_playbook_run": { data: { run_id: RUN_ID, status: "success", manual: false } }
    });
    const { raw, headers } = signed(COMPLETE_PATH, {
      n8n_execution_id: "exec-1",
      status: "success",
      result: { restarted: true }
    });

    const res = await request(app).post(COMPLETE_PATH).set(headers).type("json").send(raw);

    expect(res.status).toBe(200);
    expect(callsFor(calls, "rpc:complete_playbook_run", "rpc")[0]?.args[0]).toEqual({
      p_run_id: RUN_ID,
      p_status: "success",
      p_result: { restarted: true },
      p_n8n_execution_id: "exec-1",
      p_reason: null
    });
  });

  it("completing with another execution id is 403", async () => {
    const { app } = buildApp({
      "rpc:complete_playbook_run": { error: { code: "DC403", message: "The execution id does not match this run." } }
    });
    const { raw, headers } = signed(COMPLETE_PATH, { n8n_execution_id: "exec-x", status: "failed" });

    const res = await request(app).post(COMPLETE_PATH).set(headers).type("json").send(raw);

    expect(res.status).toBe(403);
  });

  it("validates the signed body", async () => {
    const { app, calls } = buildApp();
    const { raw, headers } = signed(COMPLETE_PATH, { n8n_execution_id: "exec-1", status: "done" });

    const res = await request(app).post(COMPLETE_PATH).set(headers).type("json").send(raw);

    expect(res.status).toBe(400);
    expect(calls).toEqual([]);
  });

  it("answers 503 when the automation identity cannot sign in", async () => {
    const { app } = buildApp({}, true);
    const { raw, headers } = signed(START_PATH, { n8n_execution_id: "exec-4" });

    const res = await request(app).post(START_PATH).set(headers).type("json").send(raw);

    expect(res.status).toBe(503);
    expect(res.body.message).toBe("Automation identity is unavailable.");
  });

  it("an expired automation session triggers a fresh sign-in next time", async () => {
    const { app, invalidate } = buildApp({
      "rpc:start_playbook_run": { error: { code: "PGRST301", message: "JWT expired" } }
    });
    vi.spyOn(console, "error").mockImplementation(() => {});
    const { raw, headers } = signed(START_PATH, { n8n_execution_id: "exec-5" });

    await request(app).post(START_PATH).set(headers).type("json").send(raw);

    expect(invalidate).toHaveBeenCalledTimes(1);
  });
});
