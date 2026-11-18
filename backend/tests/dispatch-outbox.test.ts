import { describe, expect, it, vi } from "vitest";

import { createDispatchOutbox, outboxIntervalFromEnv, type ClaimedRun } from "../src/services/dispatch-outbox.service.js";
import { sendRemediationWebhook } from "../src/services/remediation-webhook.service.js";
import { computeSignature } from "../src/middleware/machine-auth.js";

function verifySignature(secret: string, headers: Record<string, string>, method: string, path: string, body: string) {
  const expected = computeSignature(secret, {
    timestamp: Number(headers["x-dc-timestamp"]), nonce: headers["x-dc-nonce"]!, method, path, body
  });
  return headers["x-dc-signature"] === expected;
}

const SECRET = "test-only-machine-secret-0123456789abcdef";
const WEBHOOK = { url: "http://n8n.test:5678/webhook/remediation", signingSecret: SECRET };

const run = (over: Partial<ClaimedRun> = {}): ClaimedRun => ({
  run_id: "66666666-6666-4666-8666-666666666661",
  incident_id: "66666666-6666-4666-8666-666666666662",
  action_type: "rollback",
  request_payload: { service_name: "sample-app" },
  dispatch_attempts: 2,
  ...over
});

function automationReturning(result: { data?: unknown; error?: { code?: string; message?: string } | null }) {
  const rpc = vi.fn().mockResolvedValue({ data: result.data ?? null, error: result.error ?? null });
  const invalidate = vi.fn();
  return { provider: { get: vi.fn().mockResolvedValue({ rpc }), invalidate }, rpc, invalidate };
}

function fetchAnswering(...statuses: (number | Error)[]) {
  const calls: { url: string; init: RequestInit }[] = [];
  const impl = vi.fn(async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    const next = statuses.shift() ?? 202;
    if (next instanceof Error) throw next;
    return new Response("{}", { status: next });
  }) as unknown as typeof fetch;
  return { impl, calls };
}

describe("dispatch outbox", () => {
  it("claims due runs with the configured limits and sends one signed webhook each", async () => {
    const { provider, rpc } = automationReturning({ data: [run(), run({ run_id: "66666666-6666-4666-8666-666666666663", action_type: "scale" })] });
    const { impl, calls } = fetchAnswering(202, 202);
    const outbox = createDispatchOutbox(provider, WEBHOOK, { fetchImpl: impl, log: () => {}, batchSize: 5, graceSeconds: 30, retrySeconds: 45, maxAttempts: 8 });

    const results = await outbox.tick();

    expect(rpc).toHaveBeenCalledWith("claim_runs_for_dispatch", { p_limit: 5, p_grace_seconds: 30, p_retry_seconds: 45, p_max_attempts: 8 });
    expect(results.map((r) => r.outcome)).toEqual(["done", "done"]);
    expect(calls).toHaveLength(2);
    expect(calls[0]!.url).toBe(WEBHOOK.url);
    const body = JSON.parse(String(calls[0]!.init.body));
    expect(body).toEqual({ playbook_run_id: run().run_id, incident_id: run().incident_id, action_type: "rollback",
      request_payload: { service_name: "sample-app" } });
    const headers = calls[0]!.init.headers as Record<string, string>;
    expect(verifySignature(SECRET, headers, "POST", "/webhook/remediation", String(calls[0]!.init.body))).toBe(true);
    const nonce = (h: RequestInit) => (h.headers as Record<string, string>)["x-dc-nonce"];
    expect(nonce(calls[0]!.init)).not.toBe(nonce(calls[1]!.init));
  });

  it("makes ONE attempt per claim: the database decides when to try again", async () => {
    const { provider } = automationReturning({ data: [run()] });
    const { impl, calls } = fetchAnswering(503);
    const results = await createDispatchOutbox(provider, WEBHOOK, { fetchImpl: impl, log: () => {} }).tick();
    expect(results).toEqual([{ runId: run().run_id, outcome: "retry" }]);
    expect(calls).toHaveLength(1);
  });

  it("skips claimed rows with an unknown action without calling n8n", async () => {
    const { provider } = automationReturning({ data: [run({ action_type: "delete_everything" })] });
    const { impl, calls } = fetchAnswering();
    const results = await createDispatchOutbox(provider, WEBHOOK, { fetchImpl: impl, log: () => {} }).tick();
    expect(results[0]!.outcome).toBe("invalid");
    expect(calls).toHaveLength(0);
  });

  it("does nothing when no run is due", async () => {
    const { provider } = automationReturning({ data: [] });
    const { impl, calls } = fetchAnswering();
    expect(await createDispatchOutbox(provider, WEBHOOK, { fetchImpl: impl }).tick()).toEqual([]);
    expect(calls).toHaveLength(0);
  });

  it("reports a failed claim and drops the session on a JWT error", async () => {
    const { provider, invalidate } = automationReturning({ error: { code: "PGRST301", message: "JWT expired" } });
    await expect(createDispatchOutbox(provider, WEBHOOK).tick()).rejects.toThrow(/claim_runs_for_dispatch failed/);
    expect(invalidate).toHaveBeenCalled();
  });
});

describe("sendRemediationWebhook outcomes", () => {
  const payload = { playbook_run_id: run().run_id, incident_id: run().incident_id, action_type: "restart", request_payload: {} };
  it.each([
    [202, "done"], [409, "done"], [502, "retry"], [503, "retry"], [400, "failed"], [401, "failed"]
  ] as const)("HTTP %i -> %s", async (status, outcome) => {
    expect((await sendRemediationWebhook(WEBHOOK, payload, fetchAnswering(status).impl)).outcome).toBe(outcome);
  });
  it("a network error is retried later", async () => {
    expect(await sendRemediationWebhook(WEBHOOK, payload, fetchAnswering(new TypeError("fetch failed")).impl))
      .toEqual({ outcome: "retry", status: "network_error" });
  });
});

describe("REMEDIATION_OUTBOX_INTERVAL_MS", () => {
  it("defaults to 30 s, accepts 0 (off) and rejects nonsense", () => {
    expect(outboxIntervalFromEnv({})).toBe(30_000);
    expect(outboxIntervalFromEnv({ REMEDIATION_OUTBOX_INTERVAL_MS: "0" })).toBe(0);
    expect(outboxIntervalFromEnv({ REMEDIATION_OUTBOX_INTERVAL_MS: "10000" })).toBe(10_000);
    expect(() => outboxIntervalFromEnv({ REMEDIATION_OUTBOX_INTERVAL_MS: "100" })).toThrow();
    expect(() => outboxIntervalFromEnv({ REMEDIATION_OUTBOX_INTERVAL_MS: "soon" })).toThrow();
  });
});
