import type {
  NotificationDelivery,
  NotificationDeliveryStatus
} from "../services/notification-delivery.service.js";

// send() either resolves (success, or a failure returned by a channel sender)
// or throws (unexpected error, recorded as failed with a generic message).
export type NotificationSendResult =
  | {
      status: "sent" | "delivered";
      providerMessageId?: string | null;
    }
  | {
      status: "failed";
      // Already redacted by the sender (safe to store).
      errorMessage: string;
      // true = leave the delivery pending so it is claimed again later.
      retryable: boolean;
    };

export interface NotificationDeliveryProcessorDependencies {
  claim(limit: number): Promise<NotificationDelivery[]>;

  send(
    delivery: NotificationDelivery
  ): Promise<NotificationSendResult>;

  record(
    deliveryId: string,
    status: NotificationDeliveryStatus,
    providerMessageId?: string | null,
    errorMessage?: string | null
  ): Promise<void>;
}

export interface NotificationBatchResult {
  claimed: number;
  succeeded: number;
  failed: number;
  // Retryable failures left pending (not recorded) for a later attempt.
  retrying: number;
}

// Only explicitly safe provider errors are stored in the database.
// Unexpected errors are replaced with a generic message to avoid
// accidentally storing credentials or sensitive provider responses.
export class NotificationProviderError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "NotificationProviderError";
  }
}

function getSafeErrorMessage(error: unknown): string {
  if (error instanceof NotificationProviderError) {
    return error.message;
  }

  return "Notification provider request failed.";
}

export async function processNotificationDeliveryBatch(
  dependencies: NotificationDeliveryProcessorDependencies,
  limit = 50,
  // A retryable failure stays pending until the delivery was claimed this
  // many times (attempt_count is incremented by each claim); then it is
  // recorded as failed.
  maxAttempts = 5
): Promise<NotificationBatchResult> {
  const deliveries = await dependencies.claim(limit);

  const result: NotificationBatchResult = {
    claimed: deliveries.length,
    succeeded: 0,
    failed: 0,
    retrying: 0
  };

  for (const delivery of deliveries) {
    let status: NotificationDeliveryStatus;
    let providerMessageId: string | null = null;
    let errorMessage: string | null = null;

    try {
      const sendResult = await dependencies.send(delivery);

      if (sendResult.status === "failed") {
        if (sendResult.retryable && delivery.attempt_count < maxAttempts) {
          result.retrying += 1;
          continue;
        }
        status = "failed";
        errorMessage = sendResult.errorMessage.slice(0, 500);
      } else {
        status = sendResult.status;
        providerMessageId = sendResult.providerMessageId ?? null;
      }
    } catch (error) {
      status = "failed";
      errorMessage = getSafeErrorMessage(error);
    }

    // If recording fails, let the error propagate. The database's
    // claim workflow can reclaim pending deliveries after its timeout.
    await dependencies.record(
      delivery.delivery_id,
      status,
      providerMessageId,
      errorMessage
    );

    if (status === "failed") {
      result.failed += 1;
    } else {
      result.succeeded += 1;
    }
  }

  return result;
}