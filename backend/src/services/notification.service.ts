import type { UserSupabaseClient } from "../config/supabase.js";

// Retrieve the authenticated user's notification inbox.
export async function getNotifications(
  client: UserSupabaseClient,
  limit = 20,
  offset = 0
) {
  const { data, error, count } = await client
    .from("notifications")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) {
    throw error;
  }

  return {
    data: data ?? [],
    count: count ?? 0
  };
}

// Mark a notification as read using the database workflow function.
export async function markNotificationRead(
  client: UserSupabaseClient,
  notificationId: string
) {
  const { data, error } = await client.rpc(
    "mark_notification_read",
    {
      p_notification_id: notificationId
    }
  );

  if (error) {
    throw error;
  }

  return data as boolean;
}

// Register a device token for the authenticated user.
export async function registerDeviceToken(
  client: UserSupabaseClient,
  deviceToken: string,
  platform: "android" | "ios" | "web"
) {
  const { data, error } = await client.rpc(
    "register_device_token",
    {
      p_device_token: deviceToken,
      p_platform: platform
    }
  );

  if (error) {
    throw error;
  }

  return data as string;
}

// Unregister a device token belonging to the authenticated user.
export async function unregisterDeviceToken(
  client: UserSupabaseClient,
  deviceToken: string
) {
  const { data, error } = await client.rpc(
    "unregister_device_token",
    {
      p_device_token: deviceToken
    }
  );

  if (error) {
    throw error;
  }

  return data as boolean;
}
// S27: the caller's notification preferences (defaults when never saved).
export interface NotificationPreferences {
  push_enabled: boolean;
  email_enabled: boolean;
  updated_at: string | null;
}

function firstPreferencesRow(data: unknown): NotificationPreferences {
  const row = (Array.isArray(data) ? data[0] : data) as Partial<NotificationPreferences> | undefined;
  return {
    push_enabled: row?.push_enabled ?? true,
    email_enabled: row?.email_enabled ?? false,
    updated_at: row?.updated_at ?? null
  };
}

export async function getNotificationPreferences(client: UserSupabaseClient) {
  const { data, error } = await client.rpc("get_notification_preferences");
  if (error) throw error;
  return firstPreferencesRow(data);
}

export async function setNotificationPreferences(
  client: UserSupabaseClient,
  pushEnabled: boolean,
  emailEnabled: boolean
) {
  const { data, error } = await client.rpc("set_notification_preferences", {
    p_push_enabled: pushEnabled,
    p_email_enabled: emailEnabled
  });
  if (error) throw error;
  return firstPreferencesRow(data);
}
