import type { UserSupabaseClient } from "../config/supabase.js";

// Channels supported by the notification delivery database workflow.
export type NotificationChannel =
  | "push"
  | "email"
  | "slack"
  | "discord";

// Data returned by claim_notification_deliveries().
export interface NotificationDelivery {
  delivery_id: string;
  channel: NotificationChannel;
  attempt_count: number;
  notification_id: string;
  user_id: string | null;
  incident_id: string | null;
  title: string;
  message: string;
  recipient_email: string | null;
  device_tokens: string[] | null;
}

// Final statuses accepted by record_notification_delivery().
export type NotificationDeliveryStatus =
  | "sent"
  | "delivered"
  | "failed";

// Claim pending deliveries using the automation identity.
export async function claimNotificationDeliveries(
  client: UserSupabaseClient,
  limit = 50
): Promise<NotificationDelivery[]> {
  if (!Number.isInteger(limit) || limit < 1 || limit > 500) {
    throw new Error("Notification delivery limit must be between 1 and 500.");
  }

  const { data, error } = await client.rpc(
    "claim_notification_deliveries",
    {
      p_limit: limit
    }
  );

  if (error) {
    throw error;
  }

  return (data ?? []) as NotificationDelivery[];
}

// Record the result of an external notification delivery.
export async function recordNotificationDelivery(
  client: UserSupabaseClient,
  deliveryId: string,
  status: NotificationDeliveryStatus,
  providerMessageId: string | null = null,
  errorMessage: string | null = null
): Promise<void> {
  const { error } = await client.rpc(
    "record_notification_delivery",
    {
      p_delivery_id: deliveryId,
      p_status: status,
      p_provider_message_id: providerMessageId,
      p_error_message: errorMessage
    }
  );

  if (error) {
    throw error;
  }
}