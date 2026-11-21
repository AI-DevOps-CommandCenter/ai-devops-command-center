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

// BD-2: POST /api/machine/investigations/:id/analysis -> record_ai_analysis (contract B.3).
// Synthetic test secret (not a real credential).
const SECRET = "test-only-machine-secret-0123456789abcdef";
const NOW = new Date("2026-11-17T08:00:00Z");
const INCIDENT_ID = "77777777-7777-4777-8777-777777777771";
const INVESTIGATION_ID = "77777777-7777-4777-8777-777777777772";
const ANALYSIS_ID = "77777777-7777-4777-8777-777777777773";
const PATH = `/api/machine/investigations/${INVESTIGATION_ID}/analysis`;

// The body workflow 05 sends ("Sign store request").
const validBody = {
  incident_id: INCIDENT_ID,
  summary: "sample-app returns HTTP 500 for /api/orders since 08:00.",
  root_cause: "Fault injection left the order handler failing.",
  severity: "high",
  confidence: 0.82,
  evidence: [{ source: "loki", detail: "500 on /api/orders x120" }],
  recommended_action: "restart",
  model_name: "llama-3.3-70b-versatile"
};

let nonceCounter = 0;
function nonce() {
  nonceCounter += 1;
  return `analysis-test-nonce-${String(nonceCounter).padStart(6, "0")}`;
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

async function post(app: ReturnType<typeof buildApp>["app"], body: unknown, path = PATH) {
  const raw = JSON.stringify(body);
  const headers = buildSignedHeaders(SECRET, { method: "POST", path, body: raw, nonce: nonce(), now: NOW });
  return request(app).post(path).set(headers).type("json").send(raw);
}

const recorded = { "rpc:record_ai_analysis": { data: ANALYSIS_ID } };

describe("POST /api/machine/investigations/:id/analysis (BD-2)", () => {
  it("records a valid signed analysis and returns analysis_id (the key workflow 05 reads)", async () => {
    const { app, calls } = buildApp(recorded);

    const res = await post(app, validBody);

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ success: true, message: "AI analysis recorded.", data: { analysis_id: ANALYSIS_ID } });
    const rpc = callsFor(calls, "rpc:record_ai_analysis", "rpc");
    expect(rpc).toHaveLength(1);
    expect(rpc[0]?.args[0]).toEqual({
      p_incident_id: INCIDENT_ID,
      p_investigation_id: INVESTIGATION_ID,
      p_model_name: validBody.model_name,
      p_summary: validBody.summary,
      p_root_cause: validBody.root_cause,
      p_severity: "high",
      p_confidence: 0.82,
      p_evidence: validBody.evidence,
      p_recommended_action: "restart"
    });
  });

  it("optional fields default to null / []", async () => {
    const { app, calls } = buildApp(recorded);

    const res = await post(app, { incident_id: INCIDENT_ID, summary: "x" });

    expect(res.status).toBe(201);
    expect(callsFor(calls, "rpc:record_ai_analysis", "rpc")[0]?.args[0]).toMatchObject({
      p_model_name: null, p_root_cause: null, p_severity: null, p_confidence: null,
      p_evidence: [], p_recommended_action: null
    });
  });

  it("rejects an unsigned request, even with a valid user JWT", async () => {
    const { app, calls } = buildApp(recorded);

    const res = await request(app).post(PATH).set("Authorization", `Bearer ${TEST_TOKEN}`).send(validBody);

    expect(res.status).toBe(401);
    expect(calls).toEqual([]);
  });

  it.each([
    ["investigation id not a uuid", { ...validBody }, "/api/machine/investigations/not-a-uuid/analysis"],
    ["missing incident_id", { ...validBody, incident_id: undefined }, PATH],
    ["empty summary", { ...validBody, summary: "" }, PATH],
    ["severity info (no such value in ai_analyses)", { ...validBody, severity: "info" }, PATH],
    ["confidence above 1", { ...validBody, confidence: 1.5 }, PATH],
    ["confidence as string", { ...validBody, confidence: "0.5" }, PATH],
    ["evidence not an array", { ...validBody, evidence: { a: 1 } }, PATH],
    ["unknown recommended_action", { ...validBody, recommended_action: "delete_pod" }, PATH]
  ])("400 without a database call: %s", async (_name, body, path) => {
    const { app, calls } = buildApp(recorded);

    const res = await post(app, body, path);

    expect(res.status).toBe(400);
    expect(callsFor(calls, "rpc:record_ai_analysis", "rpc")).toHaveLength(0);
  });

  it("unknown incident -> 404 (DC404)", async () => {
    const { app } = buildApp({
      "rpc:record_ai_analysis": { error: { code: "DC404", message: "Incident not found." } }
    });

    const res = await post(app, validBody);

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ success: false, message: "Incident not found." });
  });

  it("investigation of another incident -> 400 (DC422)", async () => {
    const { app } = buildApp({
      "rpc:record_ai_analysis": {
        error: { code: "DC422", message: "The investigation does not belong to this incident." }
      }
    });

    const res = await post(app, validBody);

    expect(res.status).toBe(400);
  });

  it("automation sign-in failure -> 503", async () => {
    const { app } = buildApp(recorded, true);

    const res = await post(app, validBody);

    expect(res.status).toBe(503);
  });
});
