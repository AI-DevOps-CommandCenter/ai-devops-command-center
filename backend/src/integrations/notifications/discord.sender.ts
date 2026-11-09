import { httpRequest, type FetchLike } from "../http.js";
import type { DiscordConfig } from "./config.js";
import { checkDelivery, incidentLine, truncateText, webhookFailure } from "./sender-utils.js";
import type { ClaimedDelivery, DeliveryResult, NotificationSender } from "./types.js";

// Sends team broadcasts to a Discord channel through a webhook.
// https://discord.com/developers/docs/resources/webhook#execute-webhook
//
// "?wait=true" makes Discord return the created message, so its id can be
// recorded as the provider message id.

const EMBED_TITLE_MAX = 256;
const EMBED_DESCRIPTION_MAX = 4096;
const EMBED_COLOR = 0xd9534f;

export function buildDiscordPayload(delivery: ClaimedDelivery) {
  const incident = incidentLine(delivery);
  const description = incident ? `${delivery.message}\n\n${incident}` : delivery.message;

  return {
    embeds: [
      {
        title: truncateText(delivery.title, EMBED_TITLE_MAX),
        description: truncateText(description, EMBED_DESCRIPTION_MAX),
        color: EMBED_COLOR
      }
    ],
    // No @everyone, @here, role or user pings from notification text.
    allowed_mentions: { parse: [] }
  };
}

export function discordExecuteUrl(webhookUrl: string): string {
  const url = new URL(webhookUrl);
  url.searchParams.set("wait", "true");
  return url.toString();
}

function messageId(body: unknown): string | null {
  if (typeof body === "object" && body !== null && "id" in body) {
    const id = (body as { id: unknown }).id;
    return typeof id === "string" && /^\d{1,30}$/.test(id) ? id : null;
  }
  return null;
}

export class DiscordSender implements NotificationSender {
  readonly channel = "discord" as const;

  constructor(
    private readonly config: DiscordConfig,
    private readonly options: { timeoutMs: number; fetchImpl?: FetchLike }
  ) {}

  async send(delivery: ClaimedDelivery): Promise<DeliveryResult> {
    const invalid = checkDelivery(this.channel, delivery);
    if (invalid) return invalid;

    try {
      const response = await httpRequest(discordExecuteUrl(this.config.webhookUrl), {
        method: "POST",
        json: buildDiscordPayload(delivery),
        timeoutMs: this.options.timeoutMs,
        fetchImpl: this.options.fetchImpl
      });
      return { status: "sent", providerMessageId: messageId(response.body) };
    } catch (error) {
      return webhookFailure(this.channel, delivery, error);
    }
  }
}
