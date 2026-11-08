import type { UserSupabaseClient } from "../config/supabase.js";

// remediation_executions is a legacy, read-only table (decisions A2/A3).
// Client writes were revoked by migration 000700: remediation is requested,
// approved, executed and completed as a playbook run instead
// (request_playbook_run -> decide_approval -> start/complete_playbook_run).

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

const executionSelect =
  "id, incident_id, playbook_id, triggered_by, status, input_data, output_data, started_at, completed_at, created_at";

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
