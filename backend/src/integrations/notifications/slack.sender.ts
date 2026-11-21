import { httpRequest, type FetchLike } from "../http.js";
import type { SlackConfig } from "./config.js";
import { checkDelivery, incidentLine, truncateText, webhookFailure } from "./sender-utils.js";
import type { ClaimedDelivery, DeliveryResult, NotificationSender } from "./types.js";

// Sends team broadcasts to a Slack channel through an incoming webhook.
// https://api.slack.com/messaging/webhooks
//
// Slack answers 200 "ok" without a message id. Errors come back as short
// codes in the body (e.g. 404 "no_service" when the webhook was removed).

const MAX_TEXT_LENGTH = 3500;

// Escapes the three characters Slack treats as control characters, so text
// like "<!channel>" from a notification can't ping the whole channel.
export function escapeSlackText(text: string): string {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

export function buildSlackPayload(delivery: ClaimedDelivery) {
  const lines = [`*${escapeSlackText(delivery.title)}*`, escapeSlackText(delivery.message)];
  const incident = incidentLine(delivery);
  if (incident) lines.push(`_${incident}_`);

  return {
    text: truncateText(lines.join("\n"), MAX_TEXT_LENGTH),
    unfurl_links: false,
    unfurl_media: false
  };
}

function slackErrorCode(body: unknown): string | undefined {
  return typeof body === "string" && /^[a-z_]{2,60}$/.test(body.trim()) ? `(${body.trim()})` : undefined;
}

export class SlackSender implements NotificationSender {
  readonly channel = "slack" as const;

  constructor(
    private readonly config: SlackConfig,
    private readonly options: { timeoutMs: number; fetchImpl?: FetchLike }
  ) {}

  async send(delivery: ClaimedDelivery): Promise<DeliveryResult> {
    const invalid = checkDelivery(this.channel, delivery);
    if (invalid) return invalid;

    try {
      await httpRequest(this.config.webhookUrl, {
        method: "POST",
        json: buildSlackPayload(delivery),
        timeoutMs: this.options.timeoutMs,
        fetchImpl: this.options.fetchImpl
      });
      return { status: "sent", providerMessageId: null };
    } catch (error) {
      const body = (error as { body?: unknown }).body;
      return webhookFailure(this.channel, delivery, error, slackErrorCode(body));
    }
  }
}
