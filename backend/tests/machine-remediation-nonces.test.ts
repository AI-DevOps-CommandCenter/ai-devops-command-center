// KI-1 / D-N8N-6: workflow 06 claims the nonce of each webhook request in the
// database before it starts the run.
import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseModuleFactory } from "./helpers/mock-supabase-module.js";
import { createMockUserClient, callsFor } from "./helpers/supabase-mock.js";
import { testConfig } from "./helpers/config.js";
import { buildSignedHeaders, createMemoryNonceStore } from "../src/middleware/machine-auth.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

const SECRET = "test-only-machine-secret-0123456789abcdef";
const NOW = new Date("2026-11-18T12:00:00Z");
const PATH = "/api/machine/remediation-nonces";
const WEBHOOK_NONCE = "Qm9vdHN0cmFwTm9uY2UxMjM0";
const SIGNED_AT = Math.floor(NOW.getTime() / 1000) - 3;

let counter = 0;
const n8nNonce = () => `n8n-outgoing-nonce-${String(++counter).padStart(6, "0")}`;

function buildApp(results: Parameters<typeof createMockUserClient>[0] = {}) {
  const mock = createMockUserClient(results);
  const app = createApp(testConfig(), {
    machine: {
      signingSecret: SECRET,
      automation: { get: () => Promise.resolve(mock.client as never), invalidate: vi.fn() },
      nonceStore: createMemoryNonceStore(() => NOW),
      now: () => NOW
    },
    remediationDispatcher: null
  });
  return { app, calls: mock.calls };
}

function post(app: ReturnType<typeof buildApp>["app"], body: object) {
  const raw = JSON.stringify(body);
  const headers = buildSignedHeaders(SECRET, { method: "POST", path: PATH, body: raw, nonce: n8nNonce(), now: NOW });
  return request(app).post(PATH).set(headers).type("json").send(raw);
}

describe("POST /api/machine/remediation-nonces", () => {
  it("consumes the webhook nonce in the database, with its own prefix", async () => {
    const { app, calls } = buildApp({ "rpc:consume_automation_nonce": { data: null } });

    const res = await post(app, { nonce: WEBHOOK_NONCE, signed_at: SIGNED_AT });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, message: "Nonce accepted." });
    expect(callsFor(calls, "rpc:consume_automation_nonce", "rpc")[0]?.args[0]).toEqual({
      p_nonce: `webhook:${WEBHOOK_NONCE}`,
      p_signed_at: new Date(SIGNED_AT * 1000).toISOString()
    });
  });

  it("answers 409 for a replayed webhook request", async () => {
    const { app } = buildApp({ "rpc:consume_automation_nonce": { error: { code: "DC409", message: "Replayed request (nonce already used)." } } });

    const res = await post(app, { nonce: WEBHOOK_NONCE, signed_at: SIGNED_AT });

    expect(res.status).toBe(409);
    expect(res.body.message).toMatch(/Replayed request/);
  });

  it("answers 401 outside the 5 minute window", async () => {
    const { app } = buildApp({ "rpc:consume_automation_nonce": { error: { code: "DC401", message: "outside" } } });
    expect((await post(app, { nonce: WEBHOOK_NONCE, signed_at: SIGNED_AT - 3600 })).status).toBe(401);
  });

  it("fails with 5xx when the database cannot be asked (06 then fails closed)", async () => {
    const { app } = buildApp({ "rpc:consume_automation_nonce": { error: { code: "XX000", message: "boom" } } });
    expect((await post(app, { nonce: WEBHOOK_NONCE, signed_at: SIGNED_AT })).status).toBeGreaterThanOrEqual(500);
  });

  it.each([
    [{}],
    [{ nonce: "short", signed_at: SIGNED_AT }],
    [{ nonce: "has spaces in it 1234567", signed_at: SIGNED_AT }],
    [{ nonce: "x".repeat(193), signed_at: SIGNED_AT }],
    [{ nonce: WEBHOOK_NONCE, signed_at: "2026-11-18T12:00:00Z" }],
    [{ nonce: WEBHOOK_NONCE, signed_at: 1.5 }]
  ])("rejects %j with 400 without touching the database", async (body) => {
    const { app, calls } = buildApp();
    const res = await post(app, body);
    expect(res.status).toBe(400);
    expect(callsFor(calls, "rpc:consume_automation_nonce", "rpc")).toHaveLength(0);
  });

  it("requires n8n's own signature (machine auth)", async () => {
    const { app } = buildApp();
    const res = await request(app).post(PATH).send({ nonce: WEBHOOK_NONCE, signed_at: SIGNED_AT });
    expect(res.status).toBe(401);
  });
});
