import { HttpRequestError } from "../http.js";
import { safeErrorMessage } from "../redact.js";
import type { ClaimedDelivery, DeliveryResult, ExternalChannel } from "./types.js";

// Helpers shared by the channel senders.

const LABEL: Record<ExternalChannel, string> = { email: "Email", slack: "Slack", discord: "Discord" };

export function truncateText(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max - 3)}...` : text;
}

export function incidentLine(delivery: ClaimedDelivery): string {
  return delivery.incident_id ? `Incident: ${delivery.incident_id}` : "";
}

// A permanent failure for input the worker handed over (wrong channel,
// missing recipient...). Retrying cannot help.
export function invalidDelivery(channel: ExternalChannel, reason: string): DeliveryResult {
  logFailure(channel, null, "invalid_delivery");
  return { status: "failed", errorMessage: `${LABEL[channel]}: ${reason}`, retryable: false };
}

export function checkDelivery(channel: ExternalChannel, delivery: ClaimedDelivery): DeliveryResult | null {
  if (delivery.channel !== channel) {
    return invalidDelivery(channel, `delivery is for channel "${safeErrorMessage(String(delivery.channel), 20)}".`);
  }
  if (typeof delivery.title !== "string" || typeof delivery.message !== "string") {
    return invalidDelivery(channel, "delivery has no title or message.");
  }
  return null;
}

// Logs one line per failure: channel, delivery id, failure kind and HTTP
// status. Never the URL, recipient, message text or provider response.
export function logFailure(
  channel: ExternalChannel,
  deliveryId: string | null,
  kind: string,
  status?: number
) {
  console.warn(
    `[notifications] ${channel} delivery ${deliveryId ?? "-"} failed: ${kind}${status ? ` (HTTP ${status})` : ""}`
  );
}

// Converts a webhook HTTP failure into a DeliveryResult. The provider's
// short error code (e.g. Slack "no_service") is kept when it is plain text.
export function webhookFailure(
  channel: ExternalChannel,
  delivery: ClaimedDelivery,
  error: unknown,
  providerDetail?: string
): DeliveryResult {
  if (!(error instanceof HttpRequestError)) {
    logFailure(channel, delivery.delivery_id, "unexpected_error");
    return { status: "failed", errorMessage: `${LABEL[channel]}: unexpected error.`, retryable: true };
  }

  logFailure(channel, delivery.delivery_id, error.kind, error.status);

  const detail = providerDetail ? ` ${providerDetail}` : "";
  return {
    status: "failed",
    errorMessage: safeErrorMessage(`${LABEL[channel]}: ${error.message}${detail}`),
    retryable: error.retryable,
    ...(error.retryAfterMs !== undefined ? { retryAfterMs: error.retryAfterMs } : {})
  };
}
