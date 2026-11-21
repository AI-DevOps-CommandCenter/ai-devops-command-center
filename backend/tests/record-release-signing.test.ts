import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseModuleFactory } from "./helpers/mock-supabase-module.js";
import { createMockUserClient, callsFor } from "./helpers/supabase-mock.js";
import { testConfig } from "./helpers/config.js";
import { createMemoryNonceStore } from "../src/middleware/machine-auth.js";
// @ts-expect-error plain ES module without type declarations
import { buildRelease, readEnvValue, PATH } from "../../monitoring/scripts/record-release.mjs";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

// Interop: the request monitoring/scripts/record-release.mjs builds passes the
// REAL machine middleware and reaches record_deployment. Synthetic test secret.
const SECRET = "test-only-machine-secret-0123456789abcdef";
const NOW = new Date("2026-11-18T20:00:00Z");

function buildApp() {
  const mock = createMockUserClient({ "rpc:record_deployment": { data: "77777777-7777-4777-8777-777777777772" } });
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

describe("record-release.mjs signing (release.sh -> backend)", () => {
  it("builds a request the backend accepts and records the release", async () => {
    const { app, calls } = buildApp();
    const { body, headers } = buildRelease("sample-app", "v2", SECRET, NOW.getTime());

    const res = await request(app).post(PATH).set(headers).send(body);

    expect(res.status).toBe(201);
    expect(callsFor(calls, "rpc:record_deployment", "rpc")[0]?.args[0]).toEqual({
      p_service_name: "sample-app",
      p_version: "v2",
      p_status: "success",
      p_provider: "local"
    });
  });

  it("a request signed with another secret is rejected", async () => {
    const { app, calls } = buildApp();
    const { body, headers } = buildRelease("sample-app", "v2", "another-secret-0123456789abcdef-xx", NOW.getTime());

    const res = await request(app).post(PATH).set(headers).send(body);

    expect(res.status).toBe(401);
    expect(callsFor(calls, "rpc:record_deployment", "rpc")).toHaveLength(0);
  });

  it("every request gets a new nonce (a retry is not a replay)", () => {
    const a = buildRelease("sample-app", "v1", SECRET, NOW.getTime());
    const b = buildRelease("sample-app", "v1", SECRET, NOW.getTime());

    expect(a.headers["X-DC-Nonce"]).not.toBe(b.headers["X-DC-Nonce"]);
  });

  it("readEnvValue returns undefined when the .env file does not exist", () => {
    expect(readEnvValue("does-not-exist/.env", "MACHINE_SIGNING_SECRET")).toBeUndefined();
  });
});
