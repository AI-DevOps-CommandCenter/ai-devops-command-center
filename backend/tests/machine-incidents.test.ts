import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseModuleFactory } from "./helpers/mock-supabase-module.js";
import { createMockUserClient, callsFor } from "./helpers/supabase-mock.js";
import { testConfig } from "./helpers/config.js";
import {
  buildSignedHeaders,
  createMemoryNonceStore
} from "../src/middleware/machine-auth.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

// BD-1 (POST /api/machine/incidents) and BD-4 (GET .../context, POST .../postmortem).
// Synthetic test secret (not a real credential).
const SECRET = "test-only-machine-secret-0123456789abcdef";
const NOW = new Date("2026-11-17T08:00:00Z");
const INCIDENT_ID = "88888888-8888-4888-8888-888888888881";
const INVESTIGATION_ID = "88888888-8888-4888-8888-888888888882";
const POSTMORTEM_ID = "88888888-8888-4888-8888-888888888883";

let nonceCounter = 0;
function nonce() {
  nonceCounter += 1;
  return `incident-test-nonce-${String(nonceCounter).padStart(6, "0")}`;
}

function buildApp(results: Parameters<typeof createMockUserClient>[0] = {}) {
  const mock = createMockUserClient(results);
  const app = createApp(testConfig(), {
    machine: {
      signingSecret: SECRET,
      automation: { get: () => Promise.resolve(mock.client as never), invalidate: vi.fn() },
      nonceStore: createMemoryNonceStore(() => NOW),
      now: () => NOW
    }
  });
  return { app, calls: mock.calls };
}

type App = ReturnType<typeof buildApp>["app"];

async function post(app: App, path: string, body: unknown) {
  const raw = JSON.stringify(body);
  const headers = buildSignedHeaders(SECRET, { method: "POST", path, body: raw, nonce: nonce(), now: NOW });
  return request(app).post(path).set(headers).type("json").send(raw);
}

async function get(app: App, path: string) {
  const headers = buildSignedHeaders(SECRET, { method: "GET", path, body: "", nonce: nonce(), now: NOW });
  return request(app).get(path).set(headers);
}

const alertBody = {
  fingerprint: "sample-app:HighErrorRate",
  title: "HighErrorRate on sample-app",
  description: "Error rate above 5 %",
  severity: "high",
  service_name: "sample-app",
  environment: "demo",
  detected_at: "2026-11-17T07:59:00Z"
};

describe("POST /api/machine/incidents (BD-1)", () => {
  it("creates an incident and investigation -> 201 with both ids", async () => {
    const { app, calls } = buildApp({
      "rpc:create_incident_from_alert": {
        data: { incident_id: INCIDENT_ID, investigation_id: INVESTIGATION_ID, created: true }
      }
    });

    const res = await post(app, "/api/machine/incidents", alertBody);

    expect(res.status).toBe(201);
    expect(res.body.data).toEqual({ incident_id: INCIDENT_ID, investigation_id: INVESTIGATION_ID, created: true });
    expect(callsFor(calls, "rpc:create_incident_from_alert", "rpc")[0]?.args[0]).toEqual({
      p_fingerprint: alertBody.fingerprint,
      p_title: alertBody.title,
      p_description: alertBody.description,
      p_severity: "high",
      p_service_name: "sample-app",
      p_environment: "demo",
      p_detected_at: alertBody.detected_at
    });
  });

  it("a repeated alert returns the existing incident -> 200, created false", async () => {
    const { app } = buildApp({
      "rpc:create_incident_from_alert": {
        data: { incident_id: INCIDENT_ID, investigation_id: INVESTIGATION_ID, created: false }
      }
    });

    const res = await post(app, "/api/machine/incidents", alertBody);

    expect(res.status).toBe(200);
    expect(res.body.data.created).toBe(false);
  });

  it.each([
    ["missing fingerprint", { ...alertBody, fingerprint: undefined }],
    ["severity warning (not an incident severity)", { ...alertBody, severity: "warning" }],
    ["missing service_name", { ...alertBody, service_name: "" }],
    ["bad detected_at", { ...alertBody, detected_at: "yesterday" }]
  ])("400 without a database call: %s", async (_name, body) => {
    const { app, calls } = buildApp();

    const res = await post(app, "/api/machine/incidents", body);

    expect(res.status).toBe(400);
    expect(callsFor(calls, "rpc:create_incident_from_alert", "rpc")).toHaveLength(0);
  });

  it("rejects an unsigned request", async () => {
    const { app, calls } = buildApp();

    const res = await request(app).post("/api/machine/incidents").send(alertBody);

    expect(res.status).toBe(401);
    expect(calls).toEqual([]);
  });
});

describe("GET /api/machine/incidents/:id/context (BD-4)", () => {
  it("returns the context from get_incident_context (signed GET, empty body)", async () => {
    const context = { incident: { id: INCIDENT_ID }, rca: null, playbook_runs: [], recovery_checks: [], timeline: [] };
    const { app, calls } = buildApp({ "rpc:get_incident_context": { data: context } });

    const res = await get(app, `/api/machine/incidents/${INCIDENT_ID}/context`);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual(context);
    expect(callsFor(calls, "rpc:get_incident_context", "rpc")[0]?.args[0]).toEqual({ p_incident_id: INCIDENT_ID });
  });

  it("unknown incident -> 404", async () => {
    const { app } = buildApp({
      "rpc:get_incident_context": { error: { code: "DC404", message: "Incident not found." } }
    });

    const res = await get(app, `/api/machine/incidents/${INCIDENT_ID}/context`);

    expect(res.status).toBe(404);
  });
});

describe("POST /api/machine/incidents/:id/postmortem (BD-4)", () => {
  const report = {
    title: "sample-app error spike",
    summary: "sample-app returned 500s for 4 minutes.",
    timeline: [{ time: "08:00", event: "Alert fired" }, { time: "08:03", event: "Restart approved" }],
    root_cause: "Faulty order handler state.",
    impact: "Orders API unavailable for 4 minutes.",
    evidence: ["Loki: 120 x HTTP 500"],
    remediation: "Restarted sample-app after human approval.",
    recovery_result: "Healthy after restart.",
    lessons_learned: ["Alert fired quickly"],
    preventive_actions: ["Add a readiness check"]
  };
  const path = `/api/machine/incidents/${INCIDENT_ID}/postmortem`;

  it("saves the postmortem and returns postmortem_id", async () => {
    const { app, calls } = buildApp({ "rpc:save_postmortem": { data: POSTMORTEM_ID } });

    const res = await post(app, path, report);

    expect(res.status).toBe(201);
    expect(res.body.data).toEqual({ postmortem_id: POSTMORTEM_ID });
    expect(callsFor(calls, "rpc:save_postmortem", "rpc")[0]?.args[0]).toEqual({
      p_incident_id: INCIDENT_ID,
      p_summary: report.summary,
      p_root_cause: report.root_cause,
      p_impact: report.impact,
      p_timeline: report.timeline,
      p_lessons_learned: "Alert fired quickly",
      p_action_items: report.preventive_actions,
      p_report: report
    });
  });

  it.each([
    ["missing summary", { ...report, summary: undefined }],
    ["timeline entry without event", { ...report, timeline: [{ time: "08:00" }] }],
    ["evidence not a list", { ...report, evidence: "x" }]
  ])("400 without a database call: %s", async (_name, body) => {
    const { app, calls } = buildApp();

    const res = await post(app, path, body);

    expect(res.status).toBe(400);
    expect(callsFor(calls, "rpc:save_postmortem", "rpc")).toHaveLength(0);
  });
});
