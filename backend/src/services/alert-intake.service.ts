import type { UserSupabaseClient } from "../config/supabase.js";

// Incidents from alerts and postmortems (BD-1, BD-4; migration 20261117000100).
// The database functions accept only the automation identity, validate the
// values and write the audit log and timeline entries.

export const INCIDENT_SEVERITIES = ["critical", "high", "medium", "low", "info"] as const;

export interface CreateIncidentFromAlertInput {
  fingerprint: string;
  title: string;
  description: string | null;
  severity: string;
  service_name: string;
  environment: string | null;
  detected_at: string | null;
}

export interface CreatedIncident {
  incident_id: string;
  investigation_id: string | null;
  created: boolean;
}

// rpc: create_incident_from_alert(...) -> { incident_id, investigation_id, created }
//   Idempotent on the fingerprint while the incident is active.
export async function createIncidentFromAlert(
  client: UserSupabaseClient,
  input: CreateIncidentFromAlertInput
): Promise<CreatedIncident> {
  const { data, error } = await client.rpc("create_incident_from_alert", {
    p_fingerprint: input.fingerprint,
    p_title: input.title,
    p_description: input.description,
    p_severity: input.severity,
    p_service_name: input.service_name,
    p_environment: input.environment,
    p_detected_at: input.detected_at
  });

  if (error) throw error;
  const result = data as Partial<CreatedIncident> | null;
  if (!result || typeof result.incident_id !== "string" || typeof result.created !== "boolean") {
    throw new Error("create_incident_from_alert returned no incident.");
  }
  return {
    incident_id: result.incident_id,
    investigation_id: typeof result.investigation_id === "string" ? result.investigation_id : null,
    created: result.created
  };
}

// rpc: get_incident_context(p_incident_id) -> { incident, rca, playbook_runs, recovery_checks, timeline }
//   DC404 incident not found.
export async function getIncidentContext(
  client: UserSupabaseClient,
  incidentId: string
): Promise<Record<string, unknown>> {
  const { data, error } = await client.rpc("get_incident_context", { p_incident_id: incidentId });
  if (error) throw error;
  if (typeof data !== "object" || data === null) {
    throw new Error("get_incident_context returned no data.");
  }
  return data as Record<string, unknown>;
}

// The validated report of workflow 08 (automation/schemas/postmortem-output.schema.json).
export interface PostmortemReport {
  title: string;
  summary: string;
  timeline: { time: string; event: string }[];
  root_cause: string;
  impact: string;
  evidence: string[];
  remediation: string;
  recovery_result: string;
  lessons_learned: string[];
  preventive_actions: string[];
}

// rpc: save_postmortem(...) -> postmortems.id. One automation postmortem per
//   incident; a re-run updates it. The full report is kept in postmortems.report,
//   the table columns hold what the app shows.
export async function savePostmortem(
  client: UserSupabaseClient,
  incidentId: string,
  report: PostmortemReport
): Promise<string> {
  const { data, error } = await client.rpc("save_postmortem", {
    p_incident_id: incidentId,
    p_summary: report.summary,
    p_root_cause: report.root_cause,
    p_impact: report.impact,
    p_timeline: report.timeline,
    p_lessons_learned: report.lessons_learned.join("\n"),
    p_action_items: report.preventive_actions,
    p_report: report
  });

  if (error) throw error;
  if (typeof data !== "string") {
    throw new Error("save_postmortem returned no id.");
  }
  return data;
}
