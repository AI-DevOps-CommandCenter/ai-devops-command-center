import type { UserSupabaseClient } from "../config/supabase.js";

// Recommended remediation for an incident (mobile S17).
// Read with the USER's client, so RLS decides visibility: AI analyses only of
// incidents the user can see, playbooks only when enabled.

export interface Recommendation {
  analysis: Record<string, unknown> | null;
  // Enabled playbooks for the recommended action.
  playbooks: Record<string, unknown>[];
  // Every other enabled playbook: the human may choose a different action.
  other_playbooks: Record<string, unknown>[];
}

export async function getRecommendation(
  client: UserSupabaseClient,
  incidentId: string
): Promise<Recommendation> {
  const { data: analyses, error: analysisError } = await client
    .from("ai_analyses")
    .select("id, incident_id, investigation_id, summary, root_cause, severity, confidence, evidence, recommended_action, model_name, created_at")
    .eq("incident_id", incidentId)
    .order("created_at", { ascending: false })
    .limit(1);
  if (analysisError) throw analysisError;

  const analysis = (analyses?.[0] as Record<string, unknown> | undefined) ?? null;
  const action = typeof analysis?.recommended_action === "string" ? analysis.recommended_action : null;

  const { data: playbooks, error: playbookError } = await client
    .from("playbooks")
    .select("id, name, description, action_type")
    .eq("enabled", true)
    .order("name", { ascending: true });
  if (playbookError) throw playbookError;

  const all = (playbooks as Record<string, unknown>[] | null) ?? [];
  return {
    analysis,
    playbooks: action ? all.filter((p) => p.action_type === action) : [],
    other_playbooks: action ? all.filter((p) => p.action_type !== action) : all
  };
}

// Recovery checks of an incident, newest first (mobile S20). User's client: RLS.
export async function getRecoveryChecks(
  client: UserSupabaseClient,
  incidentId: string
): Promise<Record<string, unknown>[]> {
  const { data, error } = await client
    .from("recovery_checks")
    .select("id, incident_id, playbook_run_id, status, check_type, details, checked_at")
    .eq("incident_id", incidentId)
    .order("checked_at", { ascending: false })
    .limit(20);
  if (error) throw error;
  return (data as Record<string, unknown>[] | null) ?? [];
}
