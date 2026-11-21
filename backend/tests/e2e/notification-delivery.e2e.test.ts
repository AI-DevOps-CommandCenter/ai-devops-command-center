import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

import { createNotificationSenders, type ClaimedDelivery } from "../../src/integrations/notifications/index.js";
import { createSmtpTransport } from "../../src/integrations/notifications/email.sender.js";
import type { EmailConfig } from "../../src/integrations/notifications/config.js";
import { createMockUserClient } from "../helpers/supabase-mock.js";
import { runDeliveryCycle } from "./helpers/contract-worker.js";
import { loopbackOnly, reply, startHttpMock, startSmtpMock } from "./helpers/mock-servers.js";

// M7 – End-to-end notification delivery (test IDs E2E-N01..N09, see
// docs/m7/TEST_RESULTS.md).
//
// Path under test: claim rows (database contract, mocked automation client)
// -> contract worker (test stand-in for M5's worker) -> real senders
// -> real HTTP / SMTP traffic -> local mock Slack, Discord and SMTP servers
// -> record_notification_delivery parameters.
//
// Nothing is sent to real Slack, Discord or e-mail servers.

const realFetch = globalThis.fetch; // captured before tests/setup.ts blocks it
const fetchImpl = loopbackOnly(realFetch);

let slack: Awaited<ReturnType<typeof startHttpMock>>;
let discord: Awaited<ReturnType<typeof startHttpMock>>;
let smtp: Awaited<ReturnType<typeof startSmtpMock>>;

beforeAll(async () => {
  slack = await startHttpMock((req, res) => {
    if (req.path.endsWith("/ok")) return reply(res, 200, "ok");
    if (req.path.endsWith("/gone")) return reply(res, 404, "no_service");
    if (req.path.endsWith("/flaky")) return reply(res, 500, "internal_error");
    if (req.path.endsWith("/slow")) return; // never answers
    reply(res, 400, "invalid_payload");
  });
  discord = await startHttpMock((req, res) => {
    if (req.path.startsWith("/api/webhooks/1/ok")) return reply(res, 200, { id: "1200000000000000042", type: 0 });
    if (req.path.startsWith("/api/webhooks/1/limited")) {
      return reply(res, 429, { message: "You are being rate limited.", retry_after: 4 }, { "retry-after": "4" });
    }
    reply(res, 404, { message: "Unknown Webhook", code: 10015 });
  });
  smtp = await startSmtpMock({
    user: "mailer",
    password: "mailer-secret-pw",
    rcptReply: (address) =>
      address.startsWith("bounce@") ? "550 5.1.1 Mailbox does not exist" :
      address.startsWith("later@") ? "451 4.3.0 Try again later" : "250 OK"
  });
});

afterAll(async () => {
  await Promise.all([slack.close(), discord.close(), smtp.close()]);
});

beforeEach(() => {
  vi.spyOn(console, "warn").mockImplementation(() => {});
});

function emailConfig(overrides: Partial<EmailConfig> = {}): EmailConfig {
  return {
    host: "127.0.0.1",
    port: smtp.port,
    secure: false,
    requireTls: false, // the local mock has no TLS; production default is true
    user: "mailer",
    password: "mailer-secret-pw",
    from: "DevOps Alerts <alerts@example.test>",
    ...overrides
  };
}

function senders(paths: { slack?: string; discord?: string } = {}, email: Partial<EmailConfig> | null = {}) {
  const config = {
    timeoutMs: 1000,
    slack: { webhookUrl: `${slack.url}/services/T1/B1/${paths.slack ?? "ok"}` },
    discord: { webhookUrl: `${discord.url}/api/webhooks/1/${paths.discord ?? "ok"}` },
    email: email ? emailConfig(email) : null
  };
  // Same factory and SMTP transport the backend uses in production.
  return createNotificationSenders(config, {
    fetchImpl,
    ...(config.email ? { mailTransport: createSmtpTransport(config.email, config.timeoutMs) } : {})
  });
}

let seq = 0;
function row(channel: string, overrides: Partial<ClaimedDelivery> = {}): ClaimedDelivery {
  seq += 1;
  return {
    delivery_id: `d0000000-0000-4000-8000-${String(seq).padStart(12, "0")}`,
    channel,
    attempt_count: 1,
    notification_id: "n0000000-0000-4000-8000-000000000001",
    user_id: channel === "email" ? "u0000000-0000-4000-8000-000000000001" : null,
    incident_id: "i0000000-0000-4000-8000-000000000001",
    title: "Approval needed: restart checkout-api",
    message: "A playbook run is waiting for your decision.",
    recipient_email: channel === "email" ? "operator@example.test" : null,
    device_tokens: null,
    ...overrides
  };
}

function automationClient(rows: ClaimedDelivery[]) {
  return createMockUserClient({
    "rpc:claim_notification_deliveries": { data: rows, error: null },
    "rpc:record_notification_delivery": { data: null, error: null }
  });
}

function recordCalls(calls: { table: string; args: unknown[] }[]) {
  return calls.filter((c) => c.table === "rpc:record_notification_delivery").map((c) => c.args[0]);
}

describe("E2E notification delivery (claim -> send -> record)", () => {
  it("E2E-N01 delivers email, Slack and Discord and records each as sent", async () => {
    const rows = [row("email"), row("slack"), row("discord")];
    const { client, calls } = automationClient(rows);
    const slackBefore = slack.requests.length;
    const discordBefore = discord.requests.length;
    const smtpBefore = smtp.messages.length;

    const outcomes = await runDeliveryCycle(client, senders());

    expect(outcomes.map((o) => o.result.status)).toEqual(["sent", "sent", "sent"]);
    expect(calls[0]).toMatchObject({ table: "rpc:claim_notification_deliveries", args: [{ p_limit: 50 }] });

    // What the providers received
    const mail = smtp.messages[smtpBefore];
    expect(mail).toMatchObject({ from: "alerts@example.test", to: ["operator@example.test"], authenticatedAs: "mailer" });
    expect(mail.data).toContain("Subject: [DevOps Command Center] Approval needed: restart checkout-api");
    expect(mail.data).toContain("A playbook run is waiting for your decision.");

    const slackReq = slack.requests[slackBefore];
    expect(slackReq.method).toBe("POST");
    expect(slackReq.headers["content-type"]).toBe("application/json");
    expect(JSON.parse(slackReq.body).text).toContain("*Approval needed: restart checkout-api*");

    const discordReq = discord.requests[discordBefore];
    expect(discordReq.path).toBe("/api/webhooks/1/ok?wait=true");
    expect(JSON.parse(discordReq.body).allowed_mentions).toEqual({ parse: [] });

    // What the worker records
    const records = recordCalls(calls) as Array<Record<string, unknown>>;
    expect(records).toHaveLength(3);
    expect(records[0]).toMatchObject({ p_delivery_id: rows[0].delivery_id, p_status: "sent", p_error_message: null });
    expect(String(records[0].p_provider_message_id)).toMatch(/^<.+@.+>$/); // SMTP Message-ID
    expect(records[1]).toEqual({ p_delivery_id: rows[1].delivery_id, p_status: "sent", p_provider_message_id: null, p_error_message: null });
    expect(records[2]).toMatchObject({ p_status: "sent", p_provider_message_id: "1200000000000000042" });
  });

  it("E2E-N02 records a removed Slack webhook as a permanent failure, without the webhook URL", async () => {
    const { client, calls } = automationClient([row("slack")]);
    const [outcome] = await runDeliveryCycle(client, senders({ slack: "gone" }));

    expect(outcome).toMatchObject({ recorded: true, result: { status: "failed", retryable: false } });
    const [record] = recordCalls(calls) as Array<Record<string, string>>;
    expect(record.p_status).toBe("failed");
    expect(record.p_error_message).toBe("Slack: Resource not found (HTTP 404). (no_service)");
    expect(record.p_error_message).not.toContain("/services/");
  });

  it("E2E-N03 keeps a transient Slack failure pending, and records it once attempts are used up", async () => {
    const first = automationClient([row("slack", { attempt_count: 1 })]);
    const [pending] = await runDeliveryCycle(first.client, senders({ slack: "flaky" }), { maxAttempts: 3 });
    expect(pending).toMatchObject({ recorded: false, result: { status: "failed", retryable: true } });
    expect(recordCalls(first.calls)).toHaveLength(0);

    const last = automationClient([row("slack", { attempt_count: 3 })]);
    const [final] = await runDeliveryCycle(last.client, senders({ slack: "flaky" }), { maxAttempts: 3 });
    expect(final.recorded).toBe(true);
    expect(recordCalls(last.calls)[0]).toMatchObject({ p_status: "failed", p_error_message: "Slack: Provider error (HTTP 500). (internal_error)" });
  });

  it("E2E-N04 passes Discord's rate-limit wait time to the worker", async () => {
    const { client } = automationClient([row("discord")]);
    const [outcome] = await runDeliveryCycle(client, senders({ discord: "limited" }));

    expect(outcome.recorded).toBe(false);
    expect(outcome.result).toEqual({
      status: "failed",
      errorMessage: "Discord: Rate limited (HTTP 429).",
      retryable: true,
      retryAfterMs: 4000
    });
  });

  it("E2E-N05 records a bounced e-mail recipient (SMTP 550) as permanent", async () => {
    const { client, calls } = automationClient([row("email", { recipient_email: "bounce@example.test" })]);
    const [outcome] = await runDeliveryCycle(client, senders());

    expect(outcome.result).toMatchObject({ status: "failed", retryable: false });
    expect(recordCalls(calls)[0]).toMatchObject({ p_status: "failed" });
    expect(String((recordCalls(calls)[0] as { p_error_message: string }).p_error_message)).toContain("550");
  });

  it("E2E-N06 treats a temporary SMTP rejection (451) as retryable", async () => {
    const { client } = automationClient([row("email", { recipient_email: "later@example.test" })]);
    const [outcome] = await runDeliveryCycle(client, senders());

    expect(outcome).toMatchObject({ recorded: false, result: { status: "failed", retryable: true } });
  });

  it("E2E-N07 reports wrong SMTP credentials as permanent without leaking them", async () => {
    const { client, calls } = automationClient([row("email")]);
    const [outcome] = await runDeliveryCycle(client, senders({}, { password: "wrong-password-xyz" }));

    expect(outcome.result).toMatchObject({ status: "failed", retryable: false });
    const record = JSON.stringify(recordCalls(calls));
    expect(record).toContain("EAUTH");
    expect(record).not.toContain("wrong-password-xyz");
    expect(JSON.stringify((console.warn as unknown as { mock: { calls: unknown[] } }).mock.calls)).not.toContain(
      "wrong-password-xyz"
    );
  });

  it("E2E-N08 times out a provider that never answers", async () => {
    const { client } = automationClient([row("slack")]);
    const started = Date.now();
    const [outcome] = await runDeliveryCycle(client, senders({ slack: "slow" }));

    expect(outcome.result).toEqual({ status: "failed", errorMessage: "Slack: No response within 1000 ms.", retryable: true });
    expect(Date.now() - started).toBeLessThan(3000);
  }, 10_000);

  it("E2E-N09 handles unconfigured channels and a failed claim", async () => {
    const { client, calls } = automationClient([row("email")]);
    const [outcome] = await runDeliveryCycle(client, senders({}, null));
    expect(outcome.result).toMatchObject({ status: "failed", retryable: false });
    expect(recordCalls(calls)[0]).toMatchObject({ p_status: "failed", p_error_message: "Channel email is not configured." });

    const denied = createMockUserClient({
      "rpc:claim_notification_deliveries": { data: null, error: { code: "DC403", message: "Role not allowed." } }
    });
    const before = slack.requests.length + discord.requests.length;
    await expect(runDeliveryCycle(denied.client, senders())).rejects.toThrow("claim_notification_deliveries failed");
    expect(slack.requests.length + discord.requests.length).toBe(before);
  });
});
