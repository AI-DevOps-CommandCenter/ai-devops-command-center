import { beforeEach, describe, expect, it, vi } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { loadNotificationSenderConfig, type EmailConfig } from "../src/integrations/notifications/config.js";
import { SlackSender, buildSlackPayload, escapeSlackText } from "../src/integrations/notifications/slack.sender.js";
import { DiscordSender, buildDiscordPayload } from "../src/integrations/notifications/discord.sender.js";
import {
  EmailSender,
  buildEmailMessage,
  classifySmtpError,
  type MailTransport
} from "../src/integrations/notifications/email.sender.js";
import {
  createNotificationSenders,
  toRecordDeliveryParams,
  type ClaimedDelivery
} from "../src/integrations/notifications/index.js";
import { redactSecrets, safeErrorMessage } from "../src/integrations/redact.js";
import { createFakeFetch } from "./helpers/fake-fetch.js";

// M7 – Email, Slack and Discord senders, unit level (no network).

const SLACK_URL = "https://hooks.slack.com/services/T000/B000/XXXXSECRETXXXX";
const DISCORD_URL = "https://discord.com/api/webhooks/123456789/SECRET-token_abc";

function delivery(overrides: Partial<ClaimedDelivery> = {}): ClaimedDelivery {
  return {
    delivery_id: "d0000000-0000-4000-8000-000000000001",
    channel: "slack",
    attempt_count: 1,
    notification_id: "n0000000-0000-4000-8000-000000000001",
    user_id: null,
    incident_id: "i0000000-0000-4000-8000-000000000001",
    title: "Checkout latency",
    message: "p95 above 2s on checkout-api",
    recipient_email: null,
    device_tokens: null,
    ...overrides
  };
}

const emailConfig: EmailConfig = {
  host: "smtp.example.test",
  port: 587,
  secure: false,
  requireTls: true,
  user: "smtp-user",
  password: "smtp-password-123",
  from: "DevOps <alerts@example.test>"
};

let warn: ReturnType<typeof vi.spyOn>;
beforeEach(() => {
  warn = vi.spyOn(console, "warn").mockImplementation(() => {});
});

function loggedText() {
  return JSON.stringify(warn.mock.calls);
}

describe("sender configuration", () => {
  it("has no channels when nothing is set", () => {
    expect(loadNotificationSenderConfig({})).toEqual({ timeoutMs: 10_000, slack: null, discord: null, email: null });
  });

  it("loads all three channels", () => {
    const cfg = loadNotificationSenderConfig({
      SLACK_WEBHOOK_URL: SLACK_URL,
      DISCORD_WEBHOOK_URL: DISCORD_URL,
      SMTP_HOST: "smtp.example.test",
      SMTP_PORT: "465",
      SMTP_SECURE: "true",
      SMTP_USER: "u",
      SMTP_PASSWORD: "p",
      EMAIL_FROM: "DevOps <alerts@example.test>",
      NOTIFICATION_SEND_TIMEOUT_MS: "5000"
    });
    expect(cfg.timeoutMs).toBe(5000);
    expect(cfg.slack?.webhookUrl).toBe(SLACK_URL);
    expect(cfg.discord?.webhookUrl).toBe(DISCORD_URL);
    expect(cfg.email).toEqual({
      host: "smtp.example.test",
      port: 465,
      secure: true,
      requireTls: true,
      user: "u",
      password: "p",
      from: "DevOps <alerts@example.test>"
    });
  });

  it.each([
    [{ SLACK_WEBHOOK_URL: "https://evil.example/services/x" }, /SLACK_WEBHOOK_URL/],
    [{ SLACK_WEBHOOK_URL: "http://hooks.slack.com/services/x" }, /SLACK_WEBHOOK_URL/],
    [{ DISCORD_WEBHOOK_URL: "https://discord.com/api/webhooks/abc/def" }, /DISCORD_WEBHOOK_URL/],
    [{ SMTP_HOST: "smtp.example.test" }, /missing EMAIL_FROM/],
    [{ EMAIL_FROM: "a@example.test" }, /missing SMTP_HOST/],
    [{ SMTP_HOST: "h", EMAIL_FROM: "a@example.test", SMTP_USER: "u" }, /set together/],
    [{ SMTP_HOST: "h", EMAIL_FROM: "not-an-address" }, /EMAIL_FROM/],
    [{ SMTP_HOST: "h", EMAIL_FROM: "a@example.test", SMTP_PORT: "99999" }, /SMTP_PORT/],
    [{ SMTP_HOST: "h", EMAIL_FROM: "a@example.test", SMTP_SECURE: "yes" }, /SMTP_SECURE/],
    [{ NOTIFICATION_SEND_TIMEOUT_MS: "10" }, /NOTIFICATION_SEND_TIMEOUT_MS/]
  ])("rejects %j", (env, message) => {
    expect(() => loadNotificationSenderConfig(env)).toThrow(message);
  });

  it("never puts a configured secret into an error", () => {
    try {
      loadNotificationSenderConfig({ SMTP_HOST: "h", EMAIL_FROM: "a@example.test", SMTP_PASSWORD: "TopSecret!" });
    } catch (error) {
      expect(String(error)).not.toContain("TopSecret!");
    }
  });

  it("creates senders only for configured channels", () => {
    const transport: MailTransport = { sendMail: vi.fn() };
    const senders = createNotificationSenders(
      { timeoutMs: 1000, slack: { webhookUrl: SLACK_URL }, discord: null, email: emailConfig },
      { mailTransport: transport }
    );
    expect([...senders.keys()].sort()).toEqual(["email", "slack"]);
    expect(senders.get("discord")).toBeUndefined();
    expect(senders.get("push")).toBeUndefined();
  });
});

describe("record_notification_delivery parameters", () => {
  const migration = readFileSync(
    join(import.meta.dirname, "..", "..", "supabase", "migrations", "20261107000600_notifications.sql"),
    "utf8"
  );

  it("use the parameter names of the migration", () => {
    const match = /CREATE FUNCTION public\.record_notification_delivery\(([\s\S]*?)\)\s*RETURNS/.exec(migration);
    const names = [...(match?.[1] ?? "").matchAll(/(p_\w+)\s+\w/g)].map((m) => m[1]);

    expect(Object.keys(toRecordDeliveryParams("id", { status: "sent", providerMessageId: "m" }))).toEqual(names);
  });

  it("match the columns returned by claim_notification_deliveries", () => {
    const match = /claim_notification_deliveries\(p_limit integer DEFAULT 50\)\s*RETURNS TABLE \(([\s\S]*?)\)\s*LANGUAGE/.exec(migration);
    const columns = [...(match?.[1] ?? "").matchAll(/(\w+)\s+(?:uuid|text|integer)/g)].map((m) => m[1]);

    expect(Object.keys(delivery()).sort()).toEqual(columns.sort());
  });

  it("map sent and failed results", () => {
    expect(toRecordDeliveryParams("d1", { status: "sent", providerMessageId: null })).toEqual({
      p_delivery_id: "d1",
      p_status: "sent",
      p_provider_message_id: null,
      p_error_message: null
    });
    expect(toRecordDeliveryParams("d1", { status: "failed", errorMessage: "x", retryable: false })).toEqual({
      p_delivery_id: "d1",
      p_status: "failed",
      p_provider_message_id: null,
      p_error_message: "x"
    });
  });
});

describe("redaction", () => {
  it("removes webhook URLs, tokens and given secrets", () => {
    const text = `failed ${SLACK_URL} ${DISCORD_URL} ghp_abcdefghijklmnopqrstuvwxyz123 Bearer abc.def.ghi pw=hunter22`;
    const clean = redactSecrets(text, ["hunter22"]);
    expect(clean).not.toMatch(/SECRET|ghp_|abc\.def|hunter22/);
  });

  it("truncates to the 500-character column limit", () => {
    expect(safeErrorMessage("x".repeat(900))).toHaveLength(500);
  });
});

describe("SlackSender", () => {
  it("posts an escaped message to the webhook", async () => {
    const { fetchImpl, requests } = createFakeFetch([{ text: "ok" }]);
    const sender = new SlackSender({ webhookUrl: SLACK_URL }, { timeoutMs: 1000, fetchImpl });

    const result = await sender.send(delivery({ title: "<!channel> & alert", message: "a < b" }));

    expect(result).toEqual({ status: "sent", providerMessageId: null });
    expect(requests[0]).toMatchObject({ url: SLACK_URL, method: "POST" });
    expect((requests[0].body as { text: string }).text).toBe(
      "*&lt;!channel&gt; &amp; alert*\na &lt; b\n_Incident: i0000000-0000-4000-8000-000000000001_"
    );
  });

  it("escapes control characters", () => {
    expect(escapeSlackText("<@U1> & <!here>")).toBe("&lt;@U1&gt; &amp; &lt;!here&gt;");
    expect(buildSlackPayload(delivery({ message: "m".repeat(5000) })).text.length).toBeLessThanOrEqual(3500);
  });

  it("reports a removed webhook as permanent and keeps Slack's error code", async () => {
    const { fetchImpl } = createFakeFetch([{ status: 404, text: "no_service" }]);
    const result = await new SlackSender({ webhookUrl: SLACK_URL }, { timeoutMs: 1000, fetchImpl }).send(delivery());

    expect(result).toEqual({
      status: "failed",
      errorMessage: "Slack: Resource not found (HTTP 404). (no_service)",
      retryable: false
    });
  });

  it.each([
    [{ status: 500, text: "internal" }, true],
    [{ status: 429, headers: { "retry-after": "7" } }, true],
    [{ status: 400, text: "invalid_payload" }, false],
    [{ status: 403, text: "action_prohibited" }, false],
    [{ networkError: true }, true]
  ])("classifies %j (retryable=%s)", async (reply, retryable) => {
    const { fetchImpl } = createFakeFetch([reply]);
    const result = await new SlackSender({ webhookUrl: SLACK_URL }, { timeoutMs: 1000, fetchImpl }).send(delivery());

    expect(result.status).toBe("failed");
    expect(result.status === "failed" && result.retryable).toBe(retryable);
    expect(loggedText()).not.toContain("SECRET");
  });

  it("times out", async () => {
    const { fetchImpl } = createFakeFetch([{ hang: true }]);
    const result = await new SlackSender({ webhookUrl: SLACK_URL }, { timeoutMs: 1000, fetchImpl }).send(delivery());
    expect(result).toMatchObject({ status: "failed", retryable: true, errorMessage: "Slack: No response within 1000 ms." });
  }, 5000);

  it("refuses a delivery for another channel without sending", async () => {
    const { fetchImpl, requests } = createFakeFetch([]);
    const result = await new SlackSender({ webhookUrl: SLACK_URL }, { timeoutMs: 1000, fetchImpl }).send(
      delivery({ channel: "discord" })
    );
    expect(result).toMatchObject({ status: "failed", retryable: false });
    expect(requests).toHaveLength(0);
  });
});

describe("DiscordSender", () => {
  it("posts an embed with mentions disabled and returns the message id", async () => {
    const { fetchImpl, requests } = createFakeFetch([{ json: { id: "1100000000000000001", type: 0 } }]);
    const sender = new DiscordSender({ webhookUrl: DISCORD_URL }, { timeoutMs: 1000, fetchImpl });

    const result = await sender.send(delivery({ channel: "discord", message: "@everyone look" }));

    expect(result).toEqual({ status: "sent", providerMessageId: "1100000000000000001" });
    expect(requests[0].url).toBe(`${DISCORD_URL}?wait=true`);
    expect(requests[0].body).toEqual({
      embeds: [
        {
          title: "Checkout latency",
          description: "@everyone look\n\nIncident: i0000000-0000-4000-8000-000000000001",
          color: 0xd9534f
        }
      ],
      allowed_mentions: { parse: [] }
    });
  });

  it("keeps embeds within Discord's limits", () => {
    const payload = buildDiscordPayload(delivery({ title: "t".repeat(300), message: "m".repeat(5000) }));
    expect(payload.embeds[0].title.length).toBe(256);
    expect(payload.embeds[0].description.length).toBe(4096);
  });

  it("passes Discord's Retry-After on 429", async () => {
    const { fetchImpl } = createFakeFetch([
      { status: 429, json: { message: "You are being rate limited.", retry_after: 2.5 }, headers: { "retry-after": "3" } }
    ]);
    const result = await new DiscordSender({ webhookUrl: DISCORD_URL }, { timeoutMs: 1000, fetchImpl }).send(
      delivery({ channel: "discord" })
    );
    expect(result).toEqual({
      status: "failed",
      errorMessage: "Discord: Rate limited (HTTP 429).",
      retryable: true,
      retryAfterMs: 3000
    });
  });

  it("reports an unknown webhook (404) as permanent without leaking the URL", async () => {
    const { fetchImpl } = createFakeFetch([{ status: 404, json: { message: "Unknown Webhook", code: 10015 } }]);
    const result = await new DiscordSender({ webhookUrl: DISCORD_URL }, { timeoutMs: 1000, fetchImpl }).send(
      delivery({ channel: "discord" })
    );
    expect(result).toMatchObject({ status: "failed", retryable: false });
    expect(JSON.stringify(result) + loggedText()).not.toContain("SECRET-token");
  });
});

describe("EmailSender", () => {
  function sender(sendMail: MailTransport["sendMail"], timeoutMs = 1000) {
    return new EmailSender(emailConfig, { sendMail }, { timeoutMs });
  }

  const emailDelivery = () =>
    delivery({ channel: "email", user_id: "u1", recipient_email: "operator@example.test" });

  it("sends a plain-text e-mail to the claimed recipient", async () => {
    const sendMail = vi.fn().mockResolvedValue({ messageId: "<abc@example.test>", rejected: [] });
    const result = await sender(sendMail).send(emailDelivery());

    expect(result).toEqual({ status: "sent", providerMessageId: "<abc@example.test>" });
    expect(sendMail).toHaveBeenCalledWith({
      from: "DevOps <alerts@example.test>",
      to: "operator@example.test",
      subject: "[DevOps Command Center] Checkout latency",
      text: expect.stringContaining("p95 above 2s on checkout-api\n\nIncident: i0000000")
    });
  });

  it("strips line breaks from the subject (header injection)", () => {
    const msg = buildEmailMessage(delivery({ title: "Hi\r\nBcc: victim@example.test" }), "a@example.test", "b@example.test");
    expect(msg.subject).toBe("[DevOps Command Center] Hi Bcc: victim@example.test");
    expect(msg.subject).not.toMatch(/[\r\n]/);
  });

  it("refuses a delivery without a valid recipient (permanent)", async () => {
    const sendMail = vi.fn();
    for (const recipient_email of [null, "", "not-an-email"]) {
      const result = await sender(sendMail).send(delivery({ channel: "email", recipient_email }));
      expect(result).toMatchObject({ status: "failed", retryable: false });
    }
    expect(sendMail).not.toHaveBeenCalled();
  });

  it("reports a rejected recipient as permanent", async () => {
    const result = await sender(vi.fn().mockResolvedValue({ messageId: "x", rejected: ["operator@example.test"] })).send(
      emailDelivery()
    );
    expect(result).toEqual({ status: "failed", errorMessage: "Email: the SMTP server rejected the recipient.", retryable: false });
  });

  it.each([
    [{ code: "EAUTH", response: "535 auth failed for smtp-user / smtp-password-123" }, false],
    [{ code: "EENVELOPE", responseCode: 550, response: "550 mailbox unavailable" }, false],
    [{ code: "EMESSAGE", responseCode: 451, response: "451 try again later" }, true],
    [{ code: "ECONNECTION" }, true],
    [{ code: "ETIMEDOUT" }, true],
    [{ code: "SOMETHING_NEW" }, false]
  ])("classifies SMTP error %j (retryable=%s)", async (error, retryable) => {
    const result = await sender(vi.fn().mockRejectedValue(Object.assign(new Error("smtp"), error))).send(emailDelivery());

    expect(result).toMatchObject({ status: "failed", retryable });
    expect(JSON.stringify(result) + loggedText()).not.toContain("smtp-password-123");
    expect(loggedText()).not.toContain("operator@example.test");
  });

  it("gives up after the overall timeout", async () => {
    const result = await sender(() => new Promise(() => {}), 1000).send(emailDelivery());
    expect(result).toMatchObject({ status: "failed", retryable: true });
  }, 5000);

  it("redacts SMTP credentials from classified errors", () => {
    expect(classifySmtpError({ code: "EAUTH", response: "bad smtp-password-123" }, ["smtp-password-123"]).message).toBe(
      "Email: SMTP authentication failed. [EAUTH] bad [redacted]"
    );
  });
});
