import type { UserSupabaseClient } from "../config/supabase.js";

// Allowed incident severity levels
export type IncidentSeverity =
  | "critical"
  | "high"
  | "medium"
  | "low"
  | "info";

// Data required to create an incident
export interface CreateIncidentInput {
  title: string;
  description?: string;
  service_name: string;
  environment?: string;
  severity: IncidentSeverity;
}

// Filters for retrieving incidents
export interface IncidentFilters {
  status?: string;
  severity?: IncidentSeverity;
  service_name?: string;
  limit?: number;
  offset?: number;
}

// Create a new incident
export async function createIncident(
  client: UserSupabaseClient,
  input: CreateIncidentInput,
  userId: string
) {
  const { data, error } = await client
    .from("incidents")
    .insert({
      title: input.title,
      description: input.description,
      service_name: input.service_name,
      environment: input.environment,
      severity: input.severity,
      status: "open",
      source: "manual",
      created_by: userId
    })
    .select()
    .single();

  return { data, error };
}

// Retrieve incidents with optional filters
export async function getIncidents(
  client: UserSupabaseClient,
  filters: IncidentFilters = {}
) {
  const limit = Math.min(Math.max(filters.limit ?? 20, 1), 100);
  const offset = Math.max(filters.offset ?? 0, 0);

  let query = client
    .from("incidents")
    .select("*")
    .order("detected_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (filters.status) {
    query = query.eq("status", filters.status);
  }

  if (filters.severity) {
    query = query.eq("severity", filters.severity);
  }

  if (filters.service_name) {
    query = query.eq("service_name", filters.service_name);
  }

  const { data, error } = await query;

  return { data, error };
}

export async function getIncidentById(
  client: UserSupabaseClient,
  incidentId: string
) {
  const { data, error } = await client
    .from("incidents")
    .select("*")
    .eq("id", incidentId)
    .single();

  return { data, error };
}

export type IncidentStatus =
  | "open"
  | "investigating"
  | "identified"
  | "mitigating"
  | "resolved"
  | "closed";

export interface UpdateIncidentInput {
  title?: string;
  description?: string;
  service_name?: string;
  environment?: string;
  severity?: IncidentSeverity;
  status?: IncidentStatus;
}

// Update an existing incident
export async function updateIncident(
  client: UserSupabaseClient,
  incidentId: string,
  input: UpdateIncidentInput
) {
  const { data, error } = await client
    .from("incidents")
    .update({
      ...input,
      updated_at: new Date().toISOString()
    })
    .eq("id", incidentId)
    .select()
    .single();

  return { data, error };
}
