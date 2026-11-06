import type { UserSupabaseClient } from "../config/supabase.js";

export type PlaybookRunStatus =
  | "pending_approval"
  | "approved"
  | "running"
  | "success"
  | "failed"
  | "rejected"
  | "cancelled";

export interface CreatePlaybookRunInput {
  playbook_id: string;
  incident_id: string;
  request_payload?: Record<string, unknown>;
}

export interface PlaybookRunFilters {
  status?: PlaybookRunStatus;
  incident_id?: string;
}

// Create a playbook execution request
export async function createPlaybookRun(
  client: UserSupabaseClient,
  input: CreatePlaybookRunInput,
  userId: string
) {
  // Check whether the requested playbook exists and is enabled
  const { data: playbook, error: playbookError } = await client
    .from("playbooks")
    .select("id, name, action_type, enabled, requires_approval")
    .eq("id", input.playbook_id)
    .maybeSingle();

  if (playbookError) throw playbookError;

  if (!playbook || !playbook.enabled) {
    return null;
  }

  // Check whether the incident exists
  const { data: incident, error: incidentError } = await client
    .from("incidents")
    .select("id")
    .eq("id", input.incident_id)
    .maybeSingle();

  if (incidentError) throw incidentError;

  if (!incident) {
    return null;
  }

  // Determine whether approval is required
  const approvalRequired = playbook.requires_approval;

  const initialStatus: PlaybookRunStatus =
    approvalRequired ? "pending_approval" : "approved";

  const { data, error } = await client
    .from("playbook_runs")
    .insert({
      playbook_id: input.playbook_id,
      incident_id: input.incident_id,
      requested_by: userId,
      status: initialStatus,
      approval_required: approvalRequired,
      request_payload: input.request_payload ?? {},
      result_payload: {}
    })
    .select("*")
    .single();

  if (error) throw error;

  return data;
}

// Get accessible playbook runs
export async function getPlaybookRuns(
  client: UserSupabaseClient,
  filters: PlaybookRunFilters = {}
) {
  let query = client
    .from("playbook_runs")
    .select("*")
    .order("requested_at", { ascending: false });

  if (filters.status) {
    query = query.eq("status", filters.status);
  }

  if (filters.incident_id) {
    query = query.eq("incident_id", filters.incident_id);
  }

  const { data, error } = await query;

  if (error) throw error;

  return data;
}

// Get one playbook run by ID
export async function getPlaybookRunById(
  client: UserSupabaseClient,
  id: string
) {
  const { data, error } = await client
    .from("playbook_runs")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  if (error) throw error;

  return data;
}

export interface DecidePlaybookRunInput {
  status: "approved" | "rejected";
}

// Approve or reject a playbook execution request
export async function decidePlaybookRun(
  client: UserSupabaseClient,
  id: string,
  input: DecidePlaybookRunInput,
  adminId: string
) {
  const { data, error } = await client
    .from("playbook_runs")
    .update({
      status: input.status,
      approved_by: adminId,
      approved_at: new Date().toISOString()
    })
    .eq("id", id)
    .eq("status", "pending_approval")
    .eq("approval_required", true)
    .select("*")
    .maybeSingle();

  if (error) throw error;

  return data;
}

export interface UpdatePlaybookRunStatusInput {
  status: "running" | "success" | "failed" | "cancelled";
  result_payload?: Record<string, unknown>;
}

// Update the execution status and result
export async function updatePlaybookRunStatus(
  client: UserSupabaseClient,
  id: string,
  input: UpdatePlaybookRunStatusInput
) {
  const { data: existingRun, error: fetchError } = await client
    .from("playbook_runs")
    .select("id, status")
    .eq("id", id)
    .maybeSingle();

  if (fetchError) throw fetchError;

  if (!existingRun) return null;

  // Validate allowed status transitions
  const allowedTransitions: Record<string, string[]> = {
    approved: ["running", "cancelled"],
    running: ["success", "failed", "cancelled"]
  };

  if (!allowedTransitions[existingRun.status]?.includes(input.status)) {
    return null;
  }

  const updates: Record<string, unknown> = {
    status: input.status
  };

  if (input.result_payload !== undefined) {
    updates.result_payload = input.result_payload;
  }

  if (input.status === "running") {
    updates.started_at = new Date().toISOString();
  }

  if (
    input.status === "success" ||
    input.status === "failed" ||
    input.status === "cancelled"
  ) {
    updates.completed_at = new Date().toISOString();
  }

  const { data, error } = await client
    .from("playbook_runs")
    .update(updates)
    .eq("id", id)
    .eq("status", existingRun.status)
    .select("*")
    .maybeSingle();

  if (error) throw error;

  return data;
}
