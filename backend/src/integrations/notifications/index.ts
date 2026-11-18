import type { FetchLike } from "../http.js";
import { loadNotificationSenderConfig, type NotificationSenderConfig } from "./config.js";
import { DiscordSender } from "./discord.sender.js";
import { createSmtpTransport, EmailSender, type MailTransport } from "./email.sender.js";
import { SlackSender } from "./slack.sender.js";
import { createFirebaseMessaging, loadPushConfig, PushSender, type PushMessaging } from "./push.sender.js";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

// src/integrations/notifications (or dist/...) -> backend folder.
const BACKEND_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
import type { NotificationSender } from "./types.js";

// Entry point for the notification sender worker (owner: Vinuka, M5).
//
//   const senders = createNotificationSenders();          // once at startup
//   const sender = senders.get(delivery.channel);         // per claimed row
//   const result = sender ? await sender.send(delivery) : ...;
//   // then record_notification_delivery(toRecordDeliveryParams(...)),
//   // or leave a retryable failure pending so it is claimed again.
//
// Only configured channels get a sender. A missing entry means the channel
// is not configured on this backend.

export * from "./types.js";
export { loadNotificationSenderConfig } from "./config.js";
export { PushSender, buildPushMessage, loadPushConfig, type PushMessaging } from "./push.sender.js";

export interface SenderDeps {
  fetchImpl?: FetchLike;
  mailTransport?: MailTransport;
}

export function createNotificationSenders(
  config: NotificationSenderConfig = loadNotificationSenderConfig(),
  deps: SenderDeps = {}
): Map<string, NotificationSender> {
  const senders = new Map<string, NotificationSender>();
  const http = { timeoutMs: config.timeoutMs, fetchImpl: deps.fetchImpl };

  if (config.slack) senders.set("slack", new SlackSender(config.slack, http));
  if (config.discord) senders.set("discord", new DiscordSender(config.discord, http));
  if (config.email) {
    const transport = deps.mailTransport ?? createSmtpTransport(config.email, config.timeoutMs);
    senders.set("email", new EmailSender(config.email, transport, { timeoutMs: config.timeoutMs }));
  }

  return senders;
}

// Senders for every configured channel, push included. Push needs the
// Firebase service account (FIREBASE_SERVICE_ACCOUNT_FILE), read once here;
// a relative path is resolved from the backend folder.
export async function createAllNotificationSenders(
  env: NodeJS.ProcessEnv = process.env,
  deps: SenderDeps & { pushMessaging?: PushMessaging } = {}
): Promise<Map<string, NotificationSender>> {
  const senders = createNotificationSenders(loadNotificationSenderConfig(env), deps);
  const push = loadPushConfig(env);
  if (push) {
    const messaging = deps.pushMessaging ?? await createFirebaseMessaging(push, BACKEND_DIR);
    senders.set("push", new PushSender(messaging));
  }
  return senders;
}

export function isPushConfigured(env: NodeJS.ProcessEnv = process.env): boolean {
  return loadPushConfig(env) !== null;
}
