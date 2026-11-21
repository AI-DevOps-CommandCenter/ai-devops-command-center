import { describe, expect, it, vi } from "vitest";
import express from "express";
import request from "supertest";

import {
  MAX_CLOCK_SKEW_SECONDS,
  buildSignedHeaders,
  captureRawBody,
  computeSignature,
  createDatabaseNonceStore,
  createMemoryNonceStore,
  machineAuth,
  type NonceStore
} from "../src/middleware/machine-auth.js";

// Synthetic test secret (not a real credential).
const SECRET = "test-only-machine-secret-0123456789abcdef";
const NOW = new Date("2026-11-07T12:00:00Z");
const PATH = "/api/machine/playbook-runs/33333333-3333-4333-8333-333333333333/start";

function buildApp(nonceStore: NonceStore = createMemoryNonceStore(() => NOW)) {
  const app = express();
  app.use(express.json({ verify: captureRawBody }));
  app.post(
    "/api/machine/*path",
    machineAuth({ secret: SECRET, nonceStore, now: () => NOW }),
    (_req, res) => {
      res.json({ success: true });
    }
  );
  return app;
}

let nonceCounter = 0;
function freshNonce() {
  nonceCounter += 1;
  return `test-nonce-${String(nonceCounter).padStart(8, "0")}`;
}

function signed(body: object, overrides: { path?: string; now?: Date; nonce?: string } = {}) {
  const raw = JSON.stringify(body);
  return {
    raw,
    headers: buildSignedHeaders(SECRET, {
      method: "POST",
      path: overrides.path ?? PATH,
      body: raw,
      nonce: overrides.nonce ?? freshNonce(),
      now: overrides.now ?? NOW
    })
  };
}

describe("machineAuth(): n8n -> backend signed requests (A5)", () => {
  it("accepts a correctly signed, fresh request", async () => {
    const { raw, headers } = signed({ n8n_execution_id: "exec-1" });
    const res = await request(buildApp()).post(PATH).set(headers).type("json").send(raw);
    expect(res.status).toBe(200);
  });

  it("rejects a request without signature headers", async () => {
    const res = await request(buildApp()).post(PATH).send({ n8n_execution_id: "exec-1" });
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  it("rejects a wrong signature", async () => {
    const { raw, headers } = signed({ a: 1 });
    headers["x-dc-signature"] = "sha256=" + "0".repeat(64);
    const res = await request(buildApp()).post(PATH).set(headers).type("json").send(raw);
    expect(res.status).toBe(401);
  });

  it("rejects a tampered body", async () => {
    const { headers } = signed({ status: "failed" });
    const res = await request(buildApp())
      .post(PATH)
      .set(headers)
      .type("json")
      .send(JSON.stringify({ status: "success" }));
    expect(res.status).toBe(401);
  });

  it("rejects a signature made for another endpoint", async () => {
    const { raw, headers } = signed({ a: 1 }, { path: "/api/machine/recovery-checks" });
    const res = await request(buildApp()).post(PATH).set(headers).type("json").send(raw);
    expect(res.status).toBe(401);
  });

  it("rejects a signature made with another secret", async () => {
    const raw = JSON.stringify({ a: 1 });
    const nonce = freshNonce();
    const timestamp = Math.floor(NOW.getTime() / 1000);
    const res = await request(buildApp())
      .post(PATH)
      .set({
        "x-dc-timestamp": String(timestamp),
        "x-dc-nonce": nonce,
        "x-dc-signature": computeSignature("another-secret-0123456789abcdefghijk", {
          timestamp, nonce, method: "POST", path: PATH, body: raw
        })
      })
      .type("json")
      .send(raw);
    expect(res.status).toBe(401);
  });

  it("rejects stale and future timestamps (5 minute window)", async () => {
    const tooOld = new Date(NOW.getTime() - (MAX_CLOCK_SKEW_SECONDS + 1) * 1000);
    const tooNew = new Date(NOW.getTime() + (MAX_CLOCK_SKEW_SECONDS + 1) * 1000);

    for (const when of [tooOld, tooNew]) {
      const { raw, headers } = signed({ a: 1 }, { now: when });
      const res = await request(buildApp()).post(PATH).set(headers).type("json").send(raw);
      expect(res.status).toBe(401);
    }
  });

  it("rejects a replayed request (same nonce twice)", async () => {
    const app = buildApp();
    const { raw, headers } = signed({ a: 1 });

    const first = await request(app).post(PATH).set(headers).type("json").send(raw);
    const replay = await request(app).post(PATH).set(headers).type("json").send(raw);

    expect(first.status).toBe(200);
    expect(replay.status).toBe(409);
  });

  it("rejects malformed nonces", async () => {
    const { raw, headers } = signed({ a: 1 }, { nonce: "short" });
    const res = await request(buildApp()).post(PATH).set(headers).type("json").send(raw);
    expect(res.status).toBe(401);
  });

  it("fails closed when replay protection is unavailable", async () => {
    const broken: NonceStore = { consume: () => Promise.reject(new Error("db down")) };
    const { raw, headers } = signed({ a: 1 });
    const res = await request(buildApp(broken)).post(PATH).set(headers).type("json").send(raw);
    expect(res.status).toBe(503);
  });

  it("refuses to start with a short secret", () => {
    expect(() =>
      machineAuth({ secret: "too-short", nonceStore: createMemoryNonceStore() })
    ).toThrow(/at least 32/);
  });
});

describe("createDatabaseNonceStore(): consume_automation_nonce() (migration 000400)", () => {
  it("calls the database function with the nonce and signing time", async () => {
    const rpc = vi.fn().mockResolvedValue({ error: null });
    const store = createDatabaseNonceStore({ rpc });

    await expect(store.consume("test-nonce-db-0001", NOW)).resolves.toBe("ok");
    expect(rpc).toHaveBeenCalledWith("consume_automation_nonce", {
      p_nonce: "test-nonce-db-0001",
      p_signed_at: NOW.toISOString()
    });
  });

  it("maps DC409 to a replay", async () => {
    const store = createDatabaseNonceStore({
      rpc: vi.fn().mockResolvedValue({ error: { code: "DC409", message: "Replayed" } })
    });
    await expect(store.consume("test-nonce-db-0002", NOW)).resolves.toBe("replayed");
  });

  it("throws on any other database error (the middleware then fails closed)", async () => {
    const store = createDatabaseNonceStore({
      rpc: vi.fn().mockResolvedValue({ error: { code: "DC403", message: "not automation" } })
    });
    await expect(store.consume("test-nonce-db-0003", NOW)).rejects.toThrow();
  });
});

describe("buildSignedHeaders(): backend -> n8n", () => {
  it("produces headers that the same verifier accepts", async () => {
    const raw = JSON.stringify({ playbook_run_id: "r1", action_type: "restart" });
    const headers = buildSignedHeaders(SECRET, {
      method: "post", path: PATH, body: raw, nonce: freshNonce(), now: NOW
    });
    expect(headers["x-dc-signature"]).toMatch(/^sha256=[0-9a-f]{64}$/);

    const res = await request(buildApp()).post(PATH).set(headers).type("json").send(raw);
    expect(res.status).toBe(200);
  });
});
