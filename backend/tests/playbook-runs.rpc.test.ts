import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import {
  supabaseMocks,
  supabaseModuleFactory,
  mockValidUser,
  TEST_TOKEN
} from "./helpers/mock-supabase-module.js";
import {
  createMockUserClient,
  callsFor,
  type RecordedCall
} from "./helpers/supabase-mock.js";
import { testConfig } from "./helpers/config.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

const app = createApp(testConfig(), { machine: null });

const INCIDENT_ID = "44444444-4444-4444-8444-444444444441";
const PLAYBOOK_ID = "44444444-4444-4444-8444-444444444442";
const RUN_ID = "44444444-4444-4444-8444-444444444443";
const APPROVAL_ID = "44444444-4444-4444-8444-444444444444";

const runRow = {
  id: RUN_ID,
  incident_id: INCIDENT_ID,
  playbook_id: PLAYBOOK_ID,
  status: "pending_approval",
  approval_required: true
};

function useClient(results: Parameters<typeof createMockUserClient>[0]) {
  mockValidUser();
  const mock = createMockUserClient(results);
  supabaseMocks.createUserSupabaseClient.mockReturnValue(mock.client);
  return mock;
}

function expectNoDirectWrites(calls: RecordedCall[]) {
  const writes = calls.filter((call) =>
    ["insert", "update", "upsert", "delete"].includes(call.method)
  );

  expect(writes).toEqual([]);
  expect(calls.some((call) => call.table === "audit_logs")).toBe(false);
}

const auth = { Authorization: `Bearer ${TEST_TOKEN}` };

describe("Playbook run lifecycle through database functions", () => {
  it("uses the database service_name instead of a client-supplied value", async () => {
    const { calls } = useClient({
      incidents: {
        data: { service_name: "payment-service" }
      },
      "rpc:request_playbook_run": {
        data: {
          run_id: RUN_ID,
          status: "pending_approval",
          approval_id: APPROVAL_ID,
          created: true
        }
      },
      playbook_runs: { data: runRow }
    });

    const res = await request(app).post("/api/playbook-runs").set(auth).send({
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID,
      request_payload: {
        target: "checkout-api",
        service_name: "untrusted-service"
      }
    });

    expect(res.status).toBe(201);

    expect(callsFor(calls, "rpc:request_playbook_run", "rpc")[0]?.args[0])
      .toMatchObject({
        p_request_payload: {
          target: "checkout-api",
          service_name: "payment-service"
        }
      });

    expectNoDirectWrites(calls);
  });

  it("returns 404 when the incident does not exist", async () => {
    const { calls } = useClient({
      incidents: { data: null }
    });

    const res = await request(app).post("/api/playbook-runs").set(auth).send({
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID
    });

    expect(res.status).toBe(404);
    expect(res.body.message).toBe("Incident not found.");

    expect(callsFor(calls, "rpc:request_playbook_run", "rpc")).toHaveLength(0);
    expectNoDirectWrites(calls);
  });

  it("returns 400 when the incident has no service_name", async () => {
    const { calls } = useClient({
      incidents: {
        data: { service_name: null }
      }
    });

    const res = await request(app).post("/api/playbook-runs").set(auth).send({
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID
    });

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/service name/i);

    expect(callsFor(calls, "rpc:request_playbook_run", "rpc")).toHaveLength(0);
    expectNoDirectWrites(calls);
  });

  it("returns 500 when the incident service_name lookup fails", async () => {
    const { calls } = useClient({
      incidents: {
        error: { message: "Database lookup failed." }
      }
    });

    const res = await request(app).post("/api/playbook-runs").set(auth).send({
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID
    });

    expect(res.status).toBe(500);

    expect(callsFor(calls, "rpc:request_playbook_run", "rpc")).toHaveLength(0);
    expectNoDirectWrites(calls);
  });

  it("rejects a non-object request payload before calling the database", async () => {
    const { calls } = useClient({});

    const res = await request(app).post("/api/playbook-runs").set(auth).send({
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID,
      request_payload: ["not", "an", "object"]
    });

    expect(res.status).toBe(400);
    expect(calls).toEqual([]);
  });

  it("a disabled playbook is 409 with the database message", async () => {
    const { calls } = useClient({
      incidents: {
        data: { service_name: "payment-service" }
      },
      "rpc:request_playbook_run": {
        error: {
          code: "DC409",
          message: "This playbook is disabled."
        }
      }
    });

    const res = await request(app).post("/api/playbook-runs").set(auth).send({
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID
    });

    expect(res.status).toBe(409);
    expect(res.body.message).toBe("This playbook is disabled.");

    expect(callsFor(calls, "rpc:request_playbook_run", "rpc")).toHaveLength(1);
    expectNoDirectWrites(calls);
  });

  it("PATCH /:id/decision decides the run's linked approval (one approval path, A3)", async () => {
    const { calls } = useClient({
      approvals: {
        data: {
          id: APPROVAL_ID,
          playbook_run_id: RUN_ID,
          status: "pending"
        }
      },
      "rpc:decide_approval": {
        data: {
          approval_id: APPROVAL_ID,
          status: "approved",
          playbook_run_id: RUN_ID,
          run_status: "approved"
        }
      },
      playbook_runs: {
        data: { ...runRow, status: "approved" }
      }
    });

    const res = await request(app)
      .patch(`/api/playbook-runs/${RUN_ID}/decision`)
      .set(auth)
      .send({ status: "approved" });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("approved");

    expect(callsFor(calls, "approvals", "eq")[0]?.args).toEqual([
      "playbook_run_id",
      RUN_ID
    ]);

    expect(callsFor(calls, "rpc:decide_approval", "rpc")[0]?.args[0]).toEqual({
      p_approval_id: APPROVAL_ID,
      p_decision: "approved",
      p_reason: null
    });

    expectNoDirectWrites(calls);
  });

  it("PATCH /:id/decision on a legacy run without approval is 404", async () => {
    const { calls } = useClient({
      approvals: { data: null }
    });

    const res = await request(app)
      .patch(`/api/playbook-runs/${RUN_ID}/decision`)
      .set(auth)
      .send({ status: "approved" });

    expect(res.status).toBe(404);

    expect(callsFor(calls, "rpc:decide_approval", "rpc")).toHaveLength(0);
  });

  it("UNAUTHORIZED: a manager cannot approve their own run (403)", async () => {
    useClient({
      approvals: {
        data: {
          id: APPROVAL_ID,
          playbook_run_id: RUN_ID,
          status: "pending"
        }
      },
      "rpc:decide_approval": {
        error: {
          code: "DC403",
          message: "You cannot decide your own request."
        }
      }
    });

    const res = await request(app)
      .patch(`/api/playbook-runs/${RUN_ID}/decision`)
      .set(auth)
      .send({ status: "approved" });

    expect(res.status).toBe(403);
  });

  it("POST /:id/cancel -> cancel_playbook_run", async () => {
    const { calls } = useClient({
      "rpc:cancel_playbook_run": {
        data: {
          run_id: RUN_ID,
          status: "cancelled"
        }
      },
      playbook_runs: {
        data: { ...runRow, status: "cancelled" }
      }
    });

    const res = await request(app)
      .post(`/api/playbook-runs/${RUN_ID}/cancel`)
      .set(auth)
      .send({ reason: "maintenance window" });

    expect(res.status).toBe(200);

    expect(callsFor(calls, "rpc:cancel_playbook_run", "rpc")[0]?.args[0]).toEqual({
      p_run_id: RUN_ID,
      p_reason: "maintenance window"
    });

    expectNoDirectWrites(calls);
  });

  it("cancelling an approved run without a reason is 400 (DC422)", async () => {
    useClient({
      "rpc:cancel_playbook_run": {
        error: {
          code: "DC422",
          message: "A reason is required to cancel an approved or running run."
        }
      }
    });

    const res = await request(app)
      .post(`/api/playbook-runs/${RUN_ID}/cancel`)
      .set(auth)
      .send({});

    expect(res.status).toBe(400);
  });

  it("POST /:id/complete (manual override) requires a reason before calling the database", async () => {
    const { calls } = useClient({});

    const res = await request(app)
      .post(`/api/playbook-runs/${RUN_ID}/complete`)
      .set(auth)
      .send({ status: "failed" });

    expect(res.status).toBe(400);
    expect(calls).toEqual([]);
  });

  it("POST /:id/complete -> complete_playbook_run without an execution id (manual, A3-Q3)", async () => {
    const { calls } = useClient({
      "rpc:complete_playbook_run": {
        data: {
          run_id: RUN_ID,
          status: "failed",
          manual: true
        }
      },
      playbook_runs: {
        data: { ...runRow, status: "failed" }
      }
    });

    const res = await request(app)
      .post(`/api/playbook-runs/${RUN_ID}/complete`)
      .set(auth)
      .send({
        status: "failed",
        reason: "n8n crashed, checked by hand"
      });

    expect(res.status).toBe(200);

    expect(callsFor(calls, "rpc:complete_playbook_run", "rpc")[0]?.args[0]).toEqual({
      p_run_id: RUN_ID,
      p_status: "failed",
      p_result: {},
      p_n8n_execution_id: null,
      p_reason: "n8n crashed, checked by hand"
    });

    expectNoDirectWrites(calls);
  });

  it("UNAUTHORIZED: a plain user cannot complete runs (403)", async () => {
    useClient({
      "rpc:complete_playbook_run": {
        error: {
          code: "DC403",
          message: "Your role is not allowed to perform this action."
        }
      }
    });

    const res = await request(app)
      .post(`/api/playbook-runs/${RUN_ID}/complete`)
      .set(auth)
      .send({
        status: "success",
        reason: "looks fine to me"
      });

    expect(res.status).toBe(403);
  });

  it("there is no human endpoint to start a run (n8n only, A5)", async () => {
    useClient({});

    const res = await request(app)
      .post(`/api/playbook-runs/${RUN_ID}/start`)
      .set(auth)
      .send({});

    expect(res.status).toBe(404);
  });
});

describe("Remediation executions are read-only (legacy, A2/A3)", () => {
  it("POST /api/remediation-executions is 410 and writes nothing", async () => {
    const { calls } = useClient({});

    const res = await request(app)
      .post("/api/remediation-executions")
      .set(auth)
      .send({
        incident_id: INCIDENT_ID,
        status: "succeeded"
      });

    expect(res.status).toBe(410);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toMatch(/POST .*api.*playbook-runs/);
    expect(calls).toEqual([]);
  });

  it("PATCH /api/remediation-executions/:id is 410 and writes nothing", async () => {
    const { calls } = useClient({});

    const res = await request(app)
      .patch(`/api/remediation-executions/${RUN_ID}`)
      .set(auth)
      .send({ status: "succeeded" });

    expect(res.status).toBe(410);
    expect(calls).toEqual([]);
  });

  it("still requires authentication", async () => {
    const res = await request(app)
      .post("/api/remediation-executions")
      .send({});

    expect(res.status).toBe(401);
  });

  it("GET still lists legacy records", async () => {
    const legacy = [{ id: RUN_ID, status: "succeeded" }];
    const { calls } = useClient({
      remediation_executions: { data: legacy }
    });

    const res = await request(app)
      .get("/api/remediation-executions")
      .set(auth);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual(legacy);

    expectNoDirectWrites(calls);
  });
});