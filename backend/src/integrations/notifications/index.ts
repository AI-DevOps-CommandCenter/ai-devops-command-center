import type { FetchLike } from "../http.js";
import { loadNotificationSenderConfig, type NotificationSenderConfig } from "./config.js";
import { DiscordSender } from "./discord.sender.js";
import { createSmtpTransport, EmailSender, type MailTransport } from "./email.sender.js";
import { SlackSender } from "./slack.sender.js";
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
