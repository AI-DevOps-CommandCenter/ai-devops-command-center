import { z } from "zod";

// Configuration for the email, Slack and Discord senders (owner: M7).
// Provider credentials stay in the backend's environment only (decision A6).
//
// Each channel is optional: a channel without configuration gets no sender.
// A partly configured channel fails at startup and names the missing
// variable, never a value.
//
// SLACK_WEBHOOK_URL            https://hooks.slack.com/services/...
// DISCORD_WEBHOOK_URL          https://discord.com/api/webhooks/<id>/<token>
// SMTP_HOST, EMAIL_FROM        required for email
// SMTP_PORT                    default 587
// SMTP_SECURE                  "true" for implicit TLS (port 465), default false
// SMTP_REQUIRE_TLS             default true: STARTTLS is required, so the
//                              password is never sent in plain text
// SMTP_USER, SMTP_PASSWORD     both or neither
// NOTIFICATION_SEND_TIMEOUT_MS default 10000 (per delivery attempt)

export interface SlackConfig {
  webhookUrl: string;
}

export interface DiscordConfig {
  webhookUrl: string;
}

export interface EmailConfig {
  host: string;
  port: number;
  secure: boolean;
  requireTls: boolean;
  user: string | null;
  password: string | null;
  from: string;
}

export interface NotificationSenderConfig {
  timeoutMs: number;
  slack: SlackConfig | null;
  discord: DiscordConfig | null;
  email: EmailConfig | null;
}

export const SLACK_WEBHOOK_PATTERN = /^https:\/\/hooks\.slack\.com\/(services|workflows|triggers)\/[A-Za-z0-9/_-]+$/;
export const DISCORD_WEBHOOK_PATTERN =
  /^https:\/\/(?:(?:ptb|canary)\.)?discord(?:app)?\.com\/api(?:\/v\d+)?\/webhooks\/\d+\/[A-Za-z0-9_-]+$/;

function value(env: NodeJS.ProcessEnv, name: string): string {
  return env[name]?.trim() ?? "";
}

function fail(problem: string): never {
  throw new Error(`Invalid notification sender configuration: ${problem}`);
}

function parseBoolean(raw: string, name: string, fallback: boolean): boolean {
  if (raw === "") return fallback;
  if (raw === "true" || raw === "1") return true;
  if (raw === "false" || raw === "0") return false;
  return fail(`${name} must be true or false`);
}

const emailAddress = z.email();

// EMAIL_FROM may be "addr@example.com" or "Name <addr@example.com>".
function isValidFrom(from: string): boolean {
  const match = /^(?:[^<>\r\n]*<([^<>\s]+)>|([^<>\s]+))$/.exec(from);
  const address = match?.[1] ?? match?.[2];
  return address !== undefined && emailAddress.safeParse(address).success;
}

export function loadNotificationSenderConfig(env: NodeJS.ProcessEnv = process.env): NotificationSenderConfig {
  const timeoutRaw = value(env, "NOTIFICATION_SEND_TIMEOUT_MS");
  const timeoutMs = timeoutRaw === "" ? 10_000 : Number(timeoutRaw);
  if (!Number.isInteger(timeoutMs) || timeoutMs < 1000 || timeoutMs > 60_000) {
    fail("NOTIFICATION_SEND_TIMEOUT_MS must be an integer between 1000 and 60000");
  }

  const slackUrl = value(env, "SLACK_WEBHOOK_URL");
  if (slackUrl && !SLACK_WEBHOOK_PATTERN.test(slackUrl)) {
    fail("SLACK_WEBHOOK_URL must be a Slack incoming-webhook URL (https://hooks.slack.com/...)");
  }

  const discordUrl = value(env, "DISCORD_WEBHOOK_URL");
  if (discordUrl && !DISCORD_WEBHOOK_PATTERN.test(discordUrl)) {
    fail("DISCORD_WEBHOOK_URL must be a Discord webhook URL (https://discord.com/api/webhooks/<id>/<token>)");
  }

  return {
    timeoutMs,
    slack: slackUrl ? { webhookUrl: slackUrl } : null,
    discord: discordUrl ? { webhookUrl: discordUrl } : null,
    email: loadEmailConfig(env)
  };
}

function loadEmailConfig(env: NodeJS.ProcessEnv): EmailConfig | null {
  const host = value(env, "SMTP_HOST");
  const from = value(env, "EMAIL_FROM");
  const user = value(env, "SMTP_USER");
  const password = env.SMTP_PASSWORD ?? "";
  const portRaw = value(env, "SMTP_PORT");
  const secureRaw = value(env, "SMTP_SECURE");
  const requireTlsRaw = value(env, "SMTP_REQUIRE_TLS");

  const anySet = [host, from, user, password, portRaw, secureRaw, requireTlsRaw].some((v) => v !== "");
  if (!anySet) return null;

  const missing = [!host && "SMTP_HOST", !from && "EMAIL_FROM"].filter(Boolean);
  if (missing.length > 0) fail(`missing ${missing.join(", ")}`);

  if (Boolean(user) !== Boolean(password)) {
    fail("SMTP_USER and SMTP_PASSWORD must be set together");
  }

  if (!isValidFrom(from)) fail("EMAIL_FROM must be an e-mail address");

  const port = portRaw === "" ? 587 : Number(portRaw);
  if (!Number.isInteger(port) || port < 1 || port > 65535) fail("SMTP_PORT must be a port number");

  return {
    host,
    port,
    secure: parseBoolean(secureRaw, "SMTP_SECURE", false),
    requireTls: parseBoolean(requireTlsRaw, "SMTP_REQUIRE_TLS", true),
    user: user || null,
    password: password || null,
    from
  };
}
