
import type { UserSupabaseClient } from "../config/supabase.js";

export type RemediationExecutionStatus =
  | "pending"
  | "running"
  | "succeeded"
  | "failed"
  | "cancelled";

export interface RemediationExecutionFilters {
  incident_id?: string;
  playbook_id?: string;
  status?: RemediationExecutionStatus;
  limit?: number;
  offset?: number;
}

export interface CreateRemediationExecutionInput {
  incident_id: string;
  playbook_id?: string | null;
  input_data?: Record<string, unknown>;
}

export interface UpdateRemediationExecutionInput {
  status?: RemediationExecutionStatus;
  output_data?: Record<string, unknown>;
  started_at?: string | null;
  completed_at?: string | null;
}

const executionSelect =
  "id, incident_id, playbook_id, triggered_by, status, input_data, output_data, started_at, completed_at, created_at";

export async function createRemediationExecution(
  client: UserSupabaseClient,
  input: CreateRemediationExecutionInput,
  userId: string
) {
  const { data, error } = await client
    .from("remediation_executions")
    .insert({
      incident_id: input.incident_id,
      playbook_id: input.playbook_id ?? null,
      triggered_by: userId,
      status: "pending",
      input_data: input.input_data ?? {},
      output_data: {}
    })
    .select(executionSelect)
    .single();

  if (error) throw error;

  return data;
}

export async function getRemediationExecutions(
  client: UserSupabaseClient,
  filters: RemediationExecutionFilters = {}
) {
  const limit = Math.min(Math.max(filters.limit ?? 20, 1), 100);
  const offset = Math.max(filters.offset ?? 0, 0);

  let query = client
    .from("remediation_executions")
    .select(executionSelect)
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (filters.incident_id) {
    query = query.eq("incident_id", filters.incident_id);
  }

  if (filters.playbook_id) {
    query = query.eq("playbook_id", filters.playbook_id);
  }

  if (filters.status) {
    query = query.eq("status", filters.status);
  }

  const { data, error } = await query;

  if (error) throw error;

  return data;
}

export async function getRemediationExecutionById(
  client: UserSupabaseClient,
  id: string
) {
  const { data, error } = await client
    .from("remediation_executions")
    .select(executionSelect)
    .eq("id", id)
    .maybeSingle();

  if (error) throw error;

  return data;
}

export async function updateRemediationExecution(
  client: UserSupabaseClient,
  id: string,
  input: UpdateRemediationExecutionInput
) {
  const { data, error } = await client
    .from("remediation_executions")
    .update(input)
    .eq("id", id)
    .select(executionSelect)
    .maybeSingle();

  if (error) throw error;

  return data;
}
