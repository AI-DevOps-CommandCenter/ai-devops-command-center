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

// Approvals are shown with what will run: the run's playbook (name, action),
// its request payload (service_name) and the incident. Embedded through the
// foreign keys; RLS still applies to every embedded table (null if hidden).
const APPROVAL_SELECT =
  "*, playbook_runs!approvals_playbook_run_id_fkey(request_payload, playbook_id, playbooks!playbook_runs_playbook_id_fkey(name, description, action_type)), incidents!approvals_incident_id_fkey(title, service_name), requester:profiles!approvals_requested_by_fkey(full_name, email)";

type Row = Record<string, unknown>;

function asRow(value: unknown): Row | null {
  if (Array.isArray(value)) return (value[0] as Row | undefined) ?? null;
  return value && typeof value === "object" ? (value as Row) : null;
}

// Flattens the embedded rows into plain fields the mobile app reads.
export function flattenApproval(row: Row | null): Row | null {
  if (!row) return row;
  const { playbook_runs, incidents, requester, ...approval } = row;
  const run = asRow(playbook_runs);
  const playbook = asRow(run?.playbooks);
  const incident = asRow(incidents);
  const person = asRow(requester);
  const payload = asRow(run?.request_payload) ?? {};
  return {
    ...approval,
    playbook_id: run?.playbook_id ?? null,
    playbook_name: playbook?.name ?? null,
    playbook_description: playbook?.description ?? null,
    action_type: playbook?.action_type ?? null,
    request_payload: payload,
    service_name: (payload.service_name as string | undefined) ?? incident?.service_name ?? null,
    incident_title: incident?.title ?? null,
    requested_by_name: person?.full_name ?? person?.email ?? null
  };
}

export async function getApprovals(
  client: UserSupabaseClient,
  status?: string
) {
  let query = client
    .from("approvals")
    .select(APPROVAL_SELECT)
    .order("requested_at", { ascending: false });

  if (status) {
    query = query.eq("status", status);
  }

  const { data, error } = await query;

  if (error) throw error;
  return ((data as Row[] | null) ?? []).map((row) => flattenApproval(row));
}

export async function getApprovalById(
  client: UserSupabaseClient,
  id: string
) {
  const { data, error } = await client
    .from("approvals")
    .select(APPROVAL_SELECT)
    .eq("id", id)
    .maybeSingle();

  if (error) throw error;
  return flattenApproval(data as Row | null);
}

// The approval linked 1:1 to a playbook run (A3), or null for legacy runs.
export async function getApprovalByRunId(
  client: UserSupabaseClient,
  runId: string
) {
  const { data, error } = await client
    .from("approvals")
    .select(APPROVAL_SELECT)
    .eq("playbook_run_id", runId)
    .maybeSingle();

  if (error) throw error;
  return flattenApproval(data as Row | null);
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
