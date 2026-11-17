// Contract between the notification sender worker (owner: Vinuka, M5) and
// the channel senders (owner: Thilina, M7).
//
// It is derived from the approved database contract A6
// (supabase/migrations/20261107000600_notifications.sql,
// database/API_AND_INTEGRATION_CONTRACTS.md B.4):
//
//   worker: claim_notification_deliveries()  -> ClaimedDelivery rows
//   sender: send(delivery)                   -> DeliveryResult
//   worker: record_notification_delivery()   <- toRecordDeliveryParams(...)
//
// The senders only deliver. Claiming, retry policy, scheduling and recording
// stay in the worker.

// The external channels that M7 implements. `push` (Firebase) is M6's;
// `in_app` needs no delivery.
export type ExternalChannel = "email" | "slack" | "discord";

// One row returned by claim_notification_deliveries(), unchanged.
export interface ClaimedDelivery {
  delivery_id: string;
  channel: string;
  attempt_count: number;
  notification_id: string;
  user_id: string | null;
  incident_id: string | null;
  title: string;
  message: string;
  recipient_email: string | null; // set for email only
  device_tokens: string[] | null; // set for push only
}

export type DeliveryResult =
  | {
      status: "sent";
      // Provider id when the provider returns one (SMTP message id, Discord
      // message id). Slack incoming webhooks return none.
      providerMessageId: string | null;
    }
  | {
      status: "failed";
      // Redacted and at most 500 characters: safe to store and log.
      errorMessage: string;
      // true = a later attempt may succeed (timeout, 5xx, rate limit, SMTP
      // 4xx). false = permanent (bad webhook, rejected recipient, auth).
      retryable: boolean;
      // Provider-requested wait (rate limits), when known.
      retryAfterMs?: number;
    };

export interface NotificationSender {
  readonly channel: ExternalChannel;
  // Never throws: every failure is returned as { status: "failed" }.
  send(delivery: ClaimedDelivery): Promise<DeliveryResult>;
}

// Parameters for record_notification_delivery(p_delivery_id, p_status,
// p_provider_message_id, p_error_message). Names match the migration
// (checked by tests/notification-senders.test.ts).
export interface RecordDeliveryParams {
  p_delivery_id: string;
  p_status: "sent" | "failed";
  p_provider_message_id: string | null;
  p_error_message: string | null;
}

export function toRecordDeliveryParams(deliveryId: string, result: DeliveryResult): RecordDeliveryParams {
  return result.status === "sent"
    ? {
        p_delivery_id: deliveryId,
        p_status: "sent",
        p_provider_message_id: result.providerMessageId,
        p_error_message: null
      }
    : {
        p_delivery_id: deliveryId,
        p_status: "failed",
        p_provider_message_id: null,
        p_error_message: result.errorMessage
      };
}
