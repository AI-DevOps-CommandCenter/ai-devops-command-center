import type { UserSupabaseClient } from "../config/supabase.js";

export interface AdminUserFilters {
  role?: "admin" | "operator" | "user";
  limit?: number;
  offset?: number;
}

export interface UpdateUserRoleInput {
  role: "admin" | "operator" | "user";
}

// Get user profiles
export async function getUsers(
  client: UserSupabaseClient,
  filters: AdminUserFilters = {}
) {
  const limit = Math.min(Math.max(filters.limit ?? 20, 1), 100);
  const offset = Math.max(filters.offset ?? 0, 0);

  let query = client
    .from("profiles")
    .select("id, full_name, email, role, created_at, updated_at")
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (filters.role) {
    query = query.eq("role", filters.role);
  }

  const { data, error } = await query;

  if (error) throw error;

  return data;
}

// Change a user's role using the secure database function
export async function updateUserRole(
  client: UserSupabaseClient,
  userId: string,
  input: UpdateUserRoleInput
) {
  const { error } = await client.rpc("admin_update_user_role", {
    target_user_id: userId,
    new_role: input.role
  });

  if (error) throw error;

  return {
    success: true,
    message: "User role updated successfully."
  };
}