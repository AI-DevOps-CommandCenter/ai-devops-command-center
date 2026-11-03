
import type { UserSupabaseClient } from "../config/supabase.js";

export interface CreateApprovalInput {
  incident_id: string;
}

// Get the authenticated user's role
export async function getUserRole(
  client: UserSupabaseClient,
  userId: string
) {
  const { data, error } = await client
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .single();

  if (error) {
    throw error;
  }

  return data.role as string;
}

// Create a new approval request
export async function createApproval(
  client: UserSupabaseClient,
  input: CreateApprovalInput,
  userId: string
) {
  const { data, error } = await client
    .from("approvals")
    .insert({
      incident_id: input.incident_id,
      requested_by: userId,
      status: "pending"
    })
    .select("*")
    .single();

  if (error) {
    throw error;
  }

  return data;
}
export async function getApprovals(
  client: UserSupabaseClient,
  status?: string
) {
  let query = client
    .from("approvals")
    .select("*")
    .order("requested_at", { ascending: false });

  if (status) {
    query = query.eq("status", status);
  }

  const { data, error } = await query;

  if (error) throw error;
  return data;
}

export async function getApprovalById(
  client: UserSupabaseClient,
  id: string
) {
  const { data, error } = await client
    .from("approvals")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  if (error) throw error;
  return data;
}
export interface DecideApprovalInput {
  status: "approved" | "rejected";
  comments?: string;
}

// Admin approves or rejects an approval request
export async function decideApproval(
  client: UserSupabaseClient,
  id: string,
  input: DecideApprovalInput,
  adminId: string
) {
  const { data, error } = await client
    .from("approvals")
    .update({
      status: input.status,
      comments: input.comments ?? null,
      approver_id: adminId,
      decided_at: new Date().toISOString()
    })
    .eq("id", id)
    .eq("status", "pending")
    .select("*")
    .maybeSingle();

  if (error) throw error;

  return data;
}