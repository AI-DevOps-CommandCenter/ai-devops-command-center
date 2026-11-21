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

// BD-3: POST /api/machine/recovery-checks -> record_recovery_check (contract B.3).
// Synthetic test secret (not a real credential).
const SECRET = "test-only-machine-secret-0123456789abcdef";
const NOW = new Date("2026-11-10T12:00:00Z");
const PATH = "/api/machine/recovery-checks";
const INCIDENT_ID = "66666666-6666-4666-8666-666666666661";
const RUN_ID = "66666666-6666-4666-8666-666666666662";
const CHECK_ID = "66666666-6666-4666-8666-666666666663";

// The body workflow 07 sends ("Sign recovery check request").
const validBody = {
  incident_id: INCIDENT_ID,
  playbook_run_id: RUN_ID,
  status: "healthy",
  check_type: "prometheus",
  details: { verdict: "recovered", checks: [{ attempt: 1, healthy: true }], reason: null, simulated_remediation: true }
};

let nonceCounter = 0;
function nonce() {
  nonceCounter += 1;
  return `recovery-test-nonce-${String(nonceCounter).padStart(6, "0")}`;
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

function signed(body: unknown, { secret = SECRET, nonceValue = nonce(), path = PATH } = {}) {
  const raw = JSON.stringify(body);
  return {
    raw,
    headers: buildSignedHeaders(secret, { method: "POST", path, body: raw, nonce: nonceValue, now: NOW })
  };
}

async function post(app: ReturnType<typeof buildApp>["app"], body: unknown) {
  const { raw, headers } = signed(body);
  return request(app).post(PATH).set(headers).type("json").send(raw);
}

const recorded = { "rpc:record_recovery_check": { data: CHECK_ID } };

describe("POST /api/machine/recovery-checks (BD-3)", () => {
  it("records a valid signed check as the automation identity and returns recovery_check_id", async () => {
    const { app, calls } = buildApp(recorded);

    const res = await post(app, validBody);

    expect(res.status).toBe(201);
    expect(res.body).toEqual({
      success: true,
      message: "Recovery check recorded.",
      data: { recovery_check_id: CHECK_ID }
    });
    const rpc = callsFor(calls, "rpc:record_recovery_check", "rpc");
    expect(rpc).toHaveLength(1);
    expect(rpc[0]?.args[0]).toEqual({
      p_incident_id: INCIDENT_ID,
      p_playbook_run_id: RUN_ID,
      p_status: "healthy",
      p_check_type: "prometheus",
      p_details: validBody.details
    });
  });

  it("accepts every status of recovery_checks_status_check", async () => {
    for (const status of ["pending", "healthy", "unhealthy", "failed"]) {
      const { app } = buildApp(recorded);
      const res = await post(app, { ...validBody, status });
      expect(res.status, status).toBe(201);
    }
  });

  it("check_type and details are optional (null and {} are passed to the function)", async () => {
    const { app, calls } = buildApp(recorded);

    const res = await post(app, { incident_id: INCIDENT_ID, playbook_run_id: RUN_ID, status: "failed" });

    expect(res.status).toBe(201);
    expect(callsFor(calls, "rpc:record_recovery_check", "rpc")[0]?.args[0]).toEqual({
      p_incident_id: INCIDENT_ID,
      p_playbook_run_id: RUN_ID,
      p_status: "failed",
      p_check_type: null,
      p_details: {}
    });
  });

  describe("authentication (HMAC, machine-auth middleware)", () => {
    it("rejects an unsigned request, even with a valid user JWT", async () => {
      const { app, calls } = buildApp(recorded);

      const res = await request(app)
        .post(PATH)
        .set("Authorization", `Bearer ${TEST_TOKEN}`)
        .send(validBody);

      expect(res.status).toBe(401);
      expect(calls).toEqual([]);
    });

    it("rejects a signature made with another secret", async () => {
      const { app, calls } = buildApp(recorded);
      const { raw, headers } = signed(validBody, { secret: "another-secret-another-secret-another!!" });

      const res = await request(app).post(PATH).set(headers).type("json").send(raw);

      expect(res.status).toBe(401);
      expect(res.body.message).toBe("Invalid request signature.");
      expect(calls).toEqual([]);
    });

    it("rejects a tampered body (signature covers the raw body)", async () => {
      const { app, calls } = buildApp(recorded);
      const { raw, headers } = signed(validBody);

      const res = await request(app).post(PATH).set(headers).type("json").send(raw.replace("healthy", "unhealthy"));

      expect(res.status).toBe(401);
      expect(calls).toEqual([]);
    });

    it("rejects a signature for another path", async () => {
      const { app, calls } = buildApp(recorded);
      const { raw, headers } = signed(validBody, { path: `/api/machine/playbook-runs/${RUN_ID}/complete` });

      const res = await request(app).post(PATH).set(headers).type("json").send(raw);

      expect(res.status).toBe(401);
      expect(calls).toEqual([]);
    });

    it("a replayed request is 409 and the check is recorded once", async () => {
      const { app, calls } = buildApp(recorded);
      const { raw, headers } = signed(validBody);

      const first = await request(app).post(PATH).set(headers).type("json").send(raw);
      const replay = await request(app).post(PATH).set(headers).type("json").send(raw);

      expect(first.status).toBe(201);
      expect(replay.status).toBe(409);
      expect(callsFor(calls, "rpc:record_recovery_check", "rpc")).toHaveLength(1);
    });

    it("answers 503 when the machine endpoints are not configured", async () => {
      const app = createApp(testConfig(), { machine: null });

      const res = await request(app).post(PATH).send(validBody);

      expect(res.status).toBe(503);
    });
  });

  describe("validation (400, the database is not called)", () => {
    const cases: Array<[string, unknown, RegExp]> = [
      ["invalid incident_id UUID", { ...validBody, incident_id: "not-a-uuid" }, /incident_id/],
      ["invalid playbook_run_id UUID", { ...validBody, playbook_run_id: "1234" }, /playbook_run_id/],
      ["missing incident_id", { ...validBody, incident_id: undefined }, /incident_id/],
      ["missing playbook_run_id", { ...validBody, playbook_run_id: undefined }, /playbook_run_id/],
      ["missing status", { ...validBody, status: undefined }, /Status must be one of/],
      ["invalid status", { ...validBody, status: "recovered" }, /Status must be one of: pending, healthy, unhealthy, failed/],
      ["non-string status", { ...validBody, status: 1 }, /Status/],
      ["check_type longer than 100 characters", { ...validBody, check_type: "x".repeat(101) }, /check_type/],
      ["empty check_type", { ...validBody, check_type: "" }, /check_type/],
      ["non-string check_type", { ...validBody, check_type: 5 }, /check_type/],
      ["details is an array", { ...validBody, details: [1, 2] }, /Details must be a JSON object/],
      ["details is a string", { ...validBody, details: "ok" }, /Details must be a JSON object/],
      ["details is null", { ...validBody, details: null }, /Details must be a JSON object/],
      ["body is an array", [validBody], /JSON object body/]
    ];

    for (const [name, body, message] of cases) {
      it(name, async () => {
        const { app, calls } = buildApp(recorded);

        const res = await post(app, body);

        expect(res.status).toBe(400);
        expect(res.body.success).toBe(false);
        expect(res.body.message).toMatch(message);
        expect(callsFor(calls, "rpc:record_recovery_check", "rpc")).toHaveLength(0);
      });
    }

    it("accepts a check_type of exactly 100 characters", async () => {
      const { app } = buildApp(recorded);
      const res = await post(app, { ...validBody, check_type: "x".repeat(100) });
      expect(res.status).toBe(201);
    });
  });

  describe("database errors", () => {
    it("unknown incident -> 404 with the database message", async () => {
      const { app } = buildApp({
        "rpc:record_recovery_check": { error: { code: "DC404", message: "Incident not found." } }
      });

      const res = await post(app, validBody);

      expect(res.status).toBe(404);
      expect(res.body).toEqual({ success: false, message: "Incident not found." });
    });

    it("unknown playbook run (or a run of another incident) -> 400, as raised by the database (DC422)", async () => {
      const { app } = buildApp({
        "rpc:record_recovery_check": {
          error: { code: "DC422", message: "The playbook run does not belong to this incident." }
        }
      });

      const res = await post(app, validBody);

      expect(res.status).toBe(400);
      expect(res.body.message).toBe("The playbook run does not belong to this incident.");
    });

    it("details too large -> 400 (DC422)", async () => {
      const { app } = buildApp({
        "rpc:record_recovery_check": { error: { code: "DC422", message: "Details must be a JSON object (max 16 kB)." } }
      });

      const res = await post(app, validBody);

      expect(res.status).toBe(400);
    });

    it("wrong role -> 403 (DC403)", async () => {
      const { app } = buildApp({
        "rpc:record_recovery_check": { error: { code: "DC403", message: "You do not have permission to do this." } }
      });

      expect((await post(app, validBody)).status).toBe(403);
    });

    it("an unexpected database error -> 500 with a generic message (no internal details)", async () => {
      const spy = vi.spyOn(console, "error").mockImplementation(() => {});
      const { app } = buildApp({
        "rpc:record_recovery_check": {
          error: { code: "XX000", message: "internal: relation public.recovery_checks at host db.internal password=hunter2" }
        }
      });

      const res = await post(app, validBody);

      expect(res.status).toBe(500);
      expect(res.body).toEqual({ success: false, message: "Failed to record recovery check." });
      expect(JSON.stringify(res.body)).not.toMatch(/hunter2|db\.internal|relation/);
      spy.mockRestore();
    });

    it("a function result without an id -> 500", async () => {
      const spy = vi.spyOn(console, "error").mockImplementation(() => {});
      const { app } = buildApp({ "rpc:record_recovery_check": { data: null } });

      const res = await post(app, validBody);

      expect(res.status).toBe(500);
      expect(res.body.message).toBe("Failed to record recovery check.");
      spy.mockRestore();
    });

    it("answers 503 when the automation identity cannot sign in", async () => {
      const { app } = buildApp(recorded, true);

      const res = await post(app, validBody);

      expect(res.status).toBe(503);
      expect(res.body.message).toBe("Automation identity is unavailable.");
    });

    it("an expired automation session triggers a fresh sign-in next time", async () => {
      const spy = vi.spyOn(console, "error").mockImplementation(() => {});
      const { app, invalidate } = buildApp({
        "rpc:record_recovery_check": { error: { code: "PGRST301", message: "JWT expired" } }
      });

      await post(app, validBody);

      expect(invalidate).toHaveBeenCalledTimes(1);
      spy.mockRestore();
    });
  });
});
