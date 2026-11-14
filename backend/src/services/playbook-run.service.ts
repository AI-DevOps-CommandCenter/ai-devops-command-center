import type { UserSupabaseClient } from "../config/supabase.js";

// Playbook run writes go through the database workflow functions
// (migration 000700, decisions A2/A3/A4/A5). The functions enforce the
// lifecycle (pending_approval -> approved -> running -> success|failed, or
// cancelled/rejected), require a human approval for every run (A4), prevent
// duplicate execution, and write the audit entry in the same transaction.

export type PlaybookRunStatus =
  | "pending_approval"
  | "approved"
  | "running"
  | "success"
  | "failed"
  | "rejected"
  | "cancelled";

export interface PlaybookRunFilters {
  status?: PlaybookRunStatus;
  incident_id?: string;
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

export interface RequestPlaybookRunInput {
  incident_id: string;
  playbook_id: string;
  idempotency_key?: string | null;
  request_payload?: Record<string, unknown>;
}

export interface RequestPlaybookRunResult {
  run_id: string;
  status: PlaybookRunStatus;
  approval_id: string | null;
  // false when an earlier request with the same idempotency key is returned
  created: boolean;
}

// Request a run; always creates its pending approval (A4).
// Copies the authoritative incidents.service_name into request_payload
// so the automation workflow can identify the affected service.
// rpc: request_playbook_run(p_incident_id, p_playbook_id, p_idempotency_key, p_request_payload)
export async function requestPlaybookRun(
  client: UserSupabaseClient,
  input: RequestPlaybookRunInput
) {
  // Retrieve the service name from the incident.
  const { data: incident, error: incidentError } = await client
    .from("incidents")
    .select("service_name")
    .eq("id", input.incident_id)
    .maybeSingle();

  if (incidentError) {
    throw incidentError;
  }

  if (!incident) {
    throw Object.assign(new Error("Incident not found."), {
      code: "DC404"
    });
  }

  const serviceName =
    typeof incident.service_name === "string"
      ? incident.service_name.trim()
      : "";

  if (!serviceName) {
    throw Object.assign(
      new Error(
        "The incident must have a service name before requesting a playbook run."
      ),
      { code: "DC422" }
    );
  }

  // Preserve existing payload fields, but always trust the database value.
  const requestPayload = {
    ...(input.request_payload ?? {}),
    service_name: serviceName
  };

  const { data, error } = await client.rpc("request_playbook_run", {
    p_incident_id: input.incident_id,
    p_playbook_id: input.playbook_id,
    p_idempotency_key: input.idempotency_key ?? null,
    p_request_payload: requestPayload
  });

  if (error) throw error;
  return data as RequestPlaybookRunResult;
}

// Requester (pending) or admin/operator with a reason (approved/running).
// rpc: cancel_playbook_run(p_run_id, p_reason)
export async function cancelPlaybookRun(
  client: UserSupabaseClient,
  id: string,
  reason?: string | null
) {
  const { data, error } = await client.rpc("cancel_playbook_run", {
    p_run_id: id,
    p_reason: reason ?? null
  });

  if (error) throw error;
  return data as { run_id: string; status: "cancelled" };
}

export interface CompletePlaybookRunInput {
  status: "success" | "failed";
  result_payload?: Record<string, unknown>;
  n8n_execution_id?: string | null;
  reason?: string | null;
}

// Automation: completes with the execution id that started the run.
// Admin/operator: manual override, reason required (A3-Q3).
// rpc: complete_playbook_run(p_run_id, p_status, p_result, p_n8n_execution_id, p_reason)
export async function completePlaybookRun(
  client: UserSupabaseClient,
  id: string,
  input: CompletePlaybookRunInput
) {
  const { data, error } = await client.rpc("complete_playbook_run", {
    p_run_id: id,
    p_status: input.status,
    p_result: input.result_payload ?? {},
    p_n8n_execution_id: input.n8n_execution_id ?? null,
    p_reason: input.reason ?? null
  });

  if (error) throw error;
  return data as { run_id: string; status: "success" | "failed"; manual: boolean };
}

export interface StartPlaybookRunResult {
  run_id: string;
  status: "running";
  automation_run_id: string;
  incident_id: string;
  action_type: string;
  request_payload: Record<string, unknown>;
}

// Automation identity only: starts an approved run (A5).
// rpc: start_playbook_run(p_run_id, p_n8n_execution_id, p_workflow_name)
export async function startPlaybookRun(
  client: UserSupabaseClient,
  id: string,
  n8nExecutionId: string,
  workflowName = "remediation"
) {
  const { data, error } = await client.rpc("start_playbook_run", {
    p_run_id: id,
    p_n8n_execution_id: n8nExecutionId,
    p_workflow_name: workflowName
  });

  if (error) throw error;
  return data as StartPlaybookRunResult;
}