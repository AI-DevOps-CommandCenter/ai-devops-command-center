import type { UserSupabaseClient } from "../config/supabase.js";

export interface CreateInvestigationInput {
  incident_id: string;
  status?: string;
  summary?: string;
  root_cause?: string;
  evidence?: unknown[];
  ai_model?: string;
}

export interface UpdateInvestigationInput {
  status?: string;
  summary?: string;
  root_cause?: string;
  evidence?: unknown[];
  ai_model?: string;
}

// Create an investigation
export async function createInvestigation(
  client: UserSupabaseClient,
  input: CreateInvestigationInput
) {
  const { data, error } = await client
    .from("investigations")
    .insert({
      incident_id: input.incident_id,
      status: input.status ?? "pending",
      summary: input.summary ?? null,
      root_cause: input.root_cause ?? null,
      evidence: input.evidence ?? [],
      ai_model: input.ai_model ?? null
    })
    .select("*")
    .single();

  return { data, error };
}

// Get investigations belonging to an incident
export async function getInvestigationsByIncident(
  client: UserSupabaseClient,
  incidentId: string
) {
  const { data, error } = await client
    .from("investigations")
    .select("*")
    .eq("incident_id", incidentId)
    .order("created_at", { ascending: false });

  return { data, error };
}

// Get one investigation
export async function getInvestigationById(
  client: UserSupabaseClient,
  id: string
) {
  const { data, error } = await client
    .from("investigations")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  return { data, error };
}

// Update an investigation
export async function updateInvestigation(
  client: UserSupabaseClient,
  id: string,
  input: UpdateInvestigationInput
) {
  const { data, error } = await client
    .from("investigations")
    .update(input)
    .eq("id", id)
    .select("*")
    .maybeSingle();

  return { data, error };
}