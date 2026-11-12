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