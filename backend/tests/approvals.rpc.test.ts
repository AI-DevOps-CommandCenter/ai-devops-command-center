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

const INCIDENT_ID = "33333333-3333-4333-8333-333333333331";
const PLAYBOOK_ID = "33333333-3333-4333-8333-333333333332";
const RUN_ID = "33333333-3333-4333-8333-333333333333";
const APPROVAL_ID = "33333333-3333-4333-8333-333333333334";

const approvalRow = {
  id: APPROVAL_ID,
  incident_id: INCIDENT_ID,
  playbook_run_id: RUN_ID,
  status: "pending"
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

function post(path: string, body: unknown) {
  return request(app)
    .post(path)
    .set("Authorization", `Bearer ${TEST_TOKEN}`)
    .send(body as object);
}

function patch(path: string, body: unknown) {
  return request(app)
    .patch(path)
    .set("Authorization", `Bearer ${TEST_TOKEN}`)
    .send(body as object);
}

describe("POST /api/approvals -> request_playbook_run", () => {
  it("requires authentication", async () => {
    const res = await request(app)
      .post("/api/approvals")
      .send({ incident_id: INCIDENT_ID });

    expect(res.status).toBe(401);
  });

  it("requires a playbook (approvals are created together with a run, A3)", async () => {
    const { calls } = useClient({});

    const res = await post("/api/approvals", {
      incident_id: INCIDENT_ID
    });

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/playbook ID is required/);
    expect(callsFor(calls, "rpc:request_playbook_run", "rpc")).toHaveLength(0);
  });

  it("creates the run and its approval through the database function", async () => {
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
      approvals: { data: approvalRow }
    });

    const res = await post("/api/approvals", {
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID,
      idempotency_key: "mobile-key-0001"
    });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({
      success: true,
      message: "Approval request created successfully.",
      data: approvalRow
    });

    expect(callsFor(calls, "rpc:request_playbook_run", "rpc")[0]?.args[0])
      .toEqual({
        p_incident_id: INCIDENT_ID,
        p_playbook_id: PLAYBOOK_ID,
        p_idempotency_key: "mobile-key-0001",
        p_request_payload: {
          service_name: "payment-service"
        }
      });

    expectNoDirectWrites(calls);
  });

  it("returns 200 for an idempotent retry", async () => {
    useClient({
      incidents: {
        data: { service_name: "payment-service" }
      },
      "rpc:request_playbook_run": {
        data: {
          run_id: RUN_ID,
          status: "pending_approval",
          approval_id: APPROVAL_ID,
          created: false
        }
      },
      approvals: { data: approvalRow }
    });

    const res = await post("/api/approvals", {
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID,
      idempotency_key: "mobile-key-0001"
    });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe("Approval request already exists.");
  });

  it("maps a duplicate active request to 409 with the database message", async () => {
    useClient({
      incidents: {
        data: { service_name: "payment-service" }
      },
      "rpc:request_playbook_run": {
        error: {
          code: "DC409",
          message: "An active run already exists for this incident and playbook."
        }
      }
    });

    const res = await post("/api/approvals", {
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID
    });

    expect(res.status).toBe(409);
    expect(res.body).toEqual({
      success: false,
      message: "An active run already exists for this incident and playbook."
    });
  });

  it("maps an incident the caller cannot see to 404", async () => {
    useClient({
      incidents: {
        data: { service_name: "payment-service" }
      },
      "rpc:request_playbook_run": {
        error: {
          code: "DC404",
          message: "Incident not found."
        }
      }
    });

    const res = await post("/api/approvals", {
      incident_id: INCIDENT_ID,
      playbook_id: PLAYBOOK_ID
    });

    expect(res.status).toBe(404);
  });
});

describe("PATCH /api/approvals/:id/decision -> decide_approval", () => {
  it("validates the decision before calling the database", async () => {
    const { calls } = useClient({});

    const res = await patch(`/api/approvals/${APPROVAL_ID}/decision`, {
      status: "maybe"
    });

    expect(res.status).toBe(400);
    expect(callsFor(calls, "rpc:decide_approval", "rpc")).toHaveLength(0);
  });

  it("decides through the database function, passing comments as the reason", async () => {
    const decided = {
      ...approvalRow,
      status: "approved"
    };

    const { calls } = useClient({
      "rpc:decide_approval": {
        data: {
          approval_id: APPROVAL_ID,
          status: "approved",
          playbook_run_id: RUN_ID,
          run_status: "approved"
        }
      },
      approvals: { data: decided }
    });

    const res = await patch(`/api/approvals/${APPROVAL_ID}/decision`, {
      status: "approved",
      comments: "Safe to restart"
    });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      success: true,
      message: "Approval request approved successfully.",
      data: decided
    });

    expect(callsFor(calls, "rpc:decide_approval", "rpc")[0]?.args[0])
      .toEqual({
        p_approval_id: APPROVAL_ID,
        p_decision: "approved",
        p_reason: "Safe to restart"
      });

    expectNoDirectWrites(calls);
  });

  it("UNAUTHORIZED: deciding one's own request is 403", async () => {
    useClient({
      "rpc:decide_approval": {
        error: {
          code: "DC403",
          message: "You cannot decide your own request."
        }
      }
    });

    const res = await patch(`/api/approvals/${APPROVAL_ID}/decision`, {
      status: "approved"
    });

    expect(res.status).toBe(403);
    expect(res.body.message).toBe("You cannot decide your own request.");
  });

  it("UNAUTHORIZED: a plain user cannot decide (403 from the database)", async () => {
    useClient({
      "rpc:decide_approval": {
        error: {
          code: "DC403",
          message: "Your role is not allowed to perform this action."
        }
      }
    });

    const res = await patch(`/api/approvals/${APPROVAL_ID}/decision`, {
      status: "rejected"
    });

    expect(res.status).toBe(403);
  });

  it("an already decided approval is 409", async () => {
    useClient({
      "rpc:decide_approval": {
        error: {
          code: "DC409",
          message: "This approval is already approved."
        }
      }
    });

    const res = await patch(`/api/approvals/${APPROVAL_ID}/decision`, {
      status: "rejected"
    });

    expect(res.status).toBe(409);
  });

  it("unknown database errors stay a generic 500", async () => {
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

    useClient({
      "rpc:decide_approval": {
        error: { message: "connection reset" }
      }
    });

    const res = await patch(`/api/approvals/${APPROVAL_ID}/decision`, {
      status: "approved"
    });

    expect(res.status).toBe(500);
    expect(res.body).toEqual({
      success: false,
      message: "Failed to decide approval request."
    });

    expect(errorSpy).toHaveBeenCalled();
    errorSpy.mockRestore();
  });
});

describe("POST /api/approvals/:id/cancel -> cancel_approval", () => {
  it("cancels through the database function", async () => {
    const { calls } = useClient({
      "rpc:cancel_approval": {
        data: {
          approval_id: APPROVAL_ID,
          status: "cancelled",
          playbook_run_id: RUN_ID
        }
      },
      approvals: {
        data: {
          ...approvalRow,
          status: "cancelled"
        }
      }
    });

    const res = await post(`/api/approvals/${APPROVAL_ID}/cancel`, {
      reason: "not needed"
    });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("cancelled");

    expect(callsFor(calls, "rpc:cancel_approval", "rpc")[0]?.args[0])
      .toEqual({
        p_approval_id: APPROVAL_ID,
        p_reason: "not needed"
      });

    expectNoDirectWrites(calls);
  });

  it("UNAUTHORIZED: only the requester may cancel (403)", async () => {
    useClient({
      "rpc:cancel_approval": {
        error: {
          code: "DC403",
          message: "Only the requester can cancel this request."
        }
      }
    });

    const res = await post(`/api/approvals/${APPROVAL_ID}/cancel`, {});

    expect(res.status).toBe(403);
  });
});