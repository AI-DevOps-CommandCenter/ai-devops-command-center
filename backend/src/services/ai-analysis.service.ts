import type { UserSupabaseClient } from "../config/supabase.js";

// AI root-cause analysis storage (BD-2, contract B.3; sent by n8n workflow 05).
// The database function checks the incident and investigation, validates the
// value sets (table CHECKs) and writes the audit log and timeline entry.

export const AI_SEVERITIES = ["low", "medium", "high", "critical"] as const;
export const AI_ACTIONS = ["restart", "rollback", "scale", "circuit_breaker"] as const;

export interface RecordAiAnalysisInput {
  incident_id: string;
  investigation_id: string | null;
  model_name: string | null;
  summary: string;
  root_cause: string | null;
  severity: string | null;
  confidence: number | null;
  evidence: unknown[];
  recommended_action: string | null;
}

// Automation identity only.
// rpc: record_ai_analysis(p_incident_id, p_investigation_id, p_model_name, p_summary,
//   p_root_cause, p_severity, p_confidence, p_evidence, p_recommended_action)
//   DC404 incident not found; DC422 investigation of another incident or too large;
//   23514 value outside the table CHECKs. Returns the new ai_analyses.id.
export async function recordAiAnalysis(
  client: UserSupabaseClient,
  input: RecordAiAnalysisInput
): Promise<string> {
  const { data, error } = await client.rpc("record_ai_analysis", {
    p_incident_id: input.incident_id,
    p_investigation_id: input.investigation_id,
    p_model_name: input.model_name,
    p_summary: input.summary,
    p_root_cause: input.root_cause,
    p_severity: input.severity,
    p_confidence: input.confidence,
    p_evidence: input.evidence,
    p_recommended_action: input.recommended_action
  });

  if (error) throw error;
  if (typeof data !== "string") {
    throw new Error("record_ai_analysis returned no id.");
  }
  return data;
}
