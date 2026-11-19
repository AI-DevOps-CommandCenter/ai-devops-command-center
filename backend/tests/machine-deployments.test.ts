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

// Local releases: POST /api/machine/deployments (release.sh) and
// GET /api/machine/deployments (workflow 04). Synthetic test secret.
const SECRET = "test-only-machine-secret-0123456789abcdef";
const NOW = new Date("2026-11-18T20:00:00Z");
const PATH = "/api/machine/deployments";
const DEPLOYMENT_ID = "77777777-7777-4777-8777-777777777771";
const SINCE = "2026-11-18T19:00:00.000Z";
const UNTIL = "2026-11-18T20:00:00.000Z";
const LIST_PATH = `${PATH}?service_name=sample-app&since=${encodeURIComponent(SINCE)}&until=${encodeURIComponent(UNTIL)}`;

let nonceCounter = 0;
function nonce() {
  nonceCounter += 1;
  return `deployment-test-nonce-${String(nonceCounter).padStart(6, "0")}`;
}

function buildApp(results: Parameters<typeof createMockUserClient>[0] = {}, failSignIn = false) {
  const mock = createMockUserClient(results);
  const app = createApp(testConfig(), {
    machine: {
      signingSecret: SECRET,
      automation: {
        get: () =>
          failSignIn ? Promise.reject(new Error("sign-in failed")) : Promise.resolve(mock.client as never),
        invalidate: vi.fn()
      },
      nonceStore: createMemoryNonceStore(() => NOW),
      now: () => NOW
    }
  });
  return { app, calls: mock.calls };
}

async function post(app: ReturnType<typeof buildApp>["app"], body: unknown, secret = SECRET) {
  const raw = JSON.stringify(body);
  const headers = buildSignedHeaders(secret, { method: "POST", path: PATH, body: raw, nonce: nonce(), now: NOW });
  return request(app).post(PATH).set(headers).type("json").send(raw);
}

async function get(app: ReturnType<typeof buildApp>["app"], path = LIST_PATH, signedPath = path) {
  const headers = buildSignedHeaders(SECRET, { method: "GET", path: signedPath, body: "", nonce: nonce(), now: NOW });
  return request(app).get(path).set(headers);
}

const recorded = { "rpc:record_deployment": { data: DEPLOYMENT_ID } };

describe("POST /api/machine/deployments", () => {
  it("records a signed release as the automation identity", async () => {
    const { app, calls } = buildApp(recorded);

    const res = await post(app, { service_name: "sample-app", version: "v2" });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({
      success: true,
      message: "Deployment recorded.",
      data: { deployment_id: DEPLOYMENT_ID }
    });
    const rpc = callsFor(calls, "rpc:record_deployment", "rpc");
    expect(rpc).toHaveLength(1);
    expect(rpc[0]?.args[0]).toEqual({
      p_service_name: "sample-app",
      p_version: "v2",
      p_status: "success",
      p_provider: "local"
    });
  });

  it("passes status and provider when given", async () => {
    const { app, calls } = buildApp(recorded);

    const res = await post(app, { service_name: "sample-app", version: "v1", status: "failed", provider: "local" });

    expect(res.status).toBe(201);
    expect(callsFor(calls, "rpc:record_deployment", "rpc")[0]?.args[0]).toMatchObject({ p_status: "failed" });
  });

  it("rejects an unsigned request and a wrong signature without calling the database", async () => {
    const { app, calls } = buildApp(recorded);

    const unsigned = await request(app).post(PATH).send({ service_name: "sample-app", version: "v2" });
    const wrong = await post(app, { service_name: "sample-app", version: "v2" }, "another-secret-0123456789abcdef-xx");

    expect(unsigned.status).toBe(401);
    expect(wrong.status).toBe(401);
    expect(callsFor(calls, "rpc:record_deployment", "rpc")).toHaveLength(0);
  });

  it.each([
    [{ version: "v2" }, "service_name"],
    [{ service_name: "sample app", version: "v2" }, "service_name"],
    [{ service_name: "sample-app" }, "version"],
    [{ service_name: "sample-app", version: "v2; rm" }, "version"],
    [{ service_name: "sample-app", version: "v2", status: "running" }, "Status"],
    [{ service_name: "sample-app", version: "v2", provider: "Local CI" }, "provider"]
  ])("rejects %j (400, no database call)", async (body, field) => {
    const { app, calls } = buildApp(recorded);

    const res = await post(app, body);

    expect(res.status).toBe(400);
    expect(res.body.message).toContain(field);
    expect(callsFor(calls, "rpc:record_deployment", "rpc")).toHaveLength(0);
  });

  it("returns 503 when the automation identity cannot sign in", async () => {
    const { app } = buildApp(recorded, true);

    const res = await post(app, { service_name: "sample-app", version: "v2" });

    expect(res.status).toBe(503);
  });
});

describe("GET /api/machine/deployments", () => {
  const rows = [
    { id: DEPLOYMENT_ID, service_name: "sample-app", version: "v2", provider: "local", status: "success", completed_at: "2026-11-18T19:56:00+00:00" }
  ];

  it("returns recent releases from list_recent_deployments (signed GET with query string)", async () => {
    const { app, calls } = buildApp({ "rpc:list_recent_deployments": { data: rows } });

    const res = await get(app);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: { deployments: rows } });
    expect(callsFor(calls, "rpc:list_recent_deployments", "rpc")[0]?.args[0]).toEqual({
      p_service_name: "sample-app",
      p_since: SINCE,
      p_until: UNTIL
    });
  });

  it("returns an empty list when there are no releases", async () => {
    const { app } = buildApp({ "rpc:list_recent_deployments": { data: [] } });

    const res = await get(app);

    expect(res.status).toBe(200);
    expect(res.body.data.deployments).toEqual([]);
  });

  it("the query string is part of the signature", async () => {
    const { app, calls } = buildApp({ "rpc:list_recent_deployments": { data: rows } });

    // Signed for another service, sent for sample-app.
    const res = await get(app, LIST_PATH, LIST_PATH.replace("sample-app", "other-app"));

    expect(res.status).toBe(401);
    expect(callsFor(calls, "rpc:list_recent_deployments", "rpc")).toHaveLength(0);
  });

  it.each([
    [`${PATH}?since=${SINCE}&until=${UNTIL}`, "service_name"],
    [`${PATH}?service_name=sample-app&since=yesterday&until=${UNTIL}`, "ISO"],
    [`${PATH}?service_name=sample-app&since=${UNTIL}&until=${SINCE}`, "before"],
    [`${PATH}?service_name=sample-app&since=2026-11-01T00:00:00Z&until=${UNTIL}`, "7 days"]
  ])("rejects %s (400)", async (path, text) => {
    const { app, calls } = buildApp({ "rpc:list_recent_deployments": { data: rows } });

    const res = await get(app, path);

    expect(res.status).toBe(400);
    expect(res.body.message).toContain(text);
    expect(callsFor(calls, "rpc:list_recent_deployments", "rpc")).toHaveLength(0);
  });
});
