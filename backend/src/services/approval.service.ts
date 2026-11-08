import type { UserSupabaseClient } from "../config/supabase.js";

// Approval writes go through the database workflow functions
// (migration 000700, decisions A2/A3). The functions check the caller's role
// and separation of duties themselves, take the actor from the JWT, and write
// the audit entry in the same transaction, so the backend never writes the
// approvals table or the audit log directly.

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

// The approval linked 1:1 to a playbook run (A3), or null for legacy runs.
export async function getApprovalByRunId(
  client: UserSupabaseClient,
  runId: string
) {
  const { data, error } = await client
    .from("approvals")
    .select("*")
    .eq("playbook_run_id", runId)
    .maybeSingle();

  if (error) throw error;
  return data;
}

export interface DecideApprovalInput {
  status: "approved" | "rejected";
  comments?: string | null;
}

export interface DecideApprovalResult {
  approval_id: string;
  status: "approved" | "rejected";
  playbook_run_id: string | null;
  run_status: "approved" | "rejected" | null;
}

// Admin or operator approves or rejects a request (never their own).
// rpc: decide_approval(p_approval_id, p_decision, p_reason)
export async function decideApproval(
  client: UserSupabaseClient,
  id: string,
  input: DecideApprovalInput
) {
  const { data, error } = await client.rpc("decide_approval", {
    p_approval_id: id,
    p_decision: input.status,
    p_reason: input.comments ?? null
  });

  if (error) throw error;
  return data as DecideApprovalResult;
}

export interface CancelApprovalResult {
  approval_id: string;
  status: "cancelled";
  playbook_run_id: string | null;
}

// The requester withdraws a pending request (and its run).
// rpc: cancel_approval(p_approval_id, p_reason)
export async function cancelApproval(
  client: UserSupabaseClient,
  id: string,
  reason?: string | null
) {
  const { data, error } = await client.rpc("cancel_approval", {
    p_approval_id: id,
    p_reason: reason ?? null
  });

  if (error) throw error;
  return data as CancelApprovalResult;
}
