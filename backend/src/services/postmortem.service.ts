
import type { UserSupabaseClient } from "../config/supabase.js";

// Input required to create a postmortem
export interface CreatePostmortemInput {
  incident_id: string;
  summary: string;
  root_cause?: string;
  impact?: string;
  timeline?: Record<string, unknown>[];
  lessons_learned?: string;
  action_items?: Record<string, unknown>[];
}

// Filters for retrieving postmortems
export interface PostmortemFilters {
  incident_id?: string;
  limit?: number;
  offset?: number;
}

// Fields that can be updated
export interface UpdatePostmortemInput {
  summary?: string;
  root_cause?: string;
  impact?: string;
  timeline?: Record<string, unknown>[];
  lessons_learned?: string;
  action_items?: Record<string, unknown>[];
}

// Create a new postmortem
export async function createPostmortem(
  client: UserSupabaseClient,
  input: CreatePostmortemInput,
  userId: string
) {
  const { data, error } = await client
    .from("postmortems")
    .insert({
      incident_id: input.incident_id,
      summary: input.summary,
      root_cause: input.root_cause ?? null,
      impact: input.impact ?? null,
      timeline: input.timeline ?? [],
      lessons_learned: input.lessons_learned ?? null,
      action_items: input.action_items ?? [],
      created_by: userId
    })
    .select("*")
    .single();

  if (error) throw error;

  return data;
}

// Get all accessible postmortems
export async function getPostmortems(
  client: UserSupabaseClient,
  filters: PostmortemFilters = {}
) {
  const limit = Math.min(
    Math.max(filters.limit ?? 20, 1),
    100
  );

  const offset = Math.max(filters.offset ?? 0, 0);

  let query = client
    .from("postmortems")
    .select("*")
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (filters.incident_id) {
    query = query.eq("incident_id", filters.incident_id);
  }

  const { data, error } = await query;

  if (error) throw error;

  return data;
}

// Get one postmortem by ID
export async function getPostmortemById(
  client: UserSupabaseClient,
  id: string
) {
  const { data, error } = await client
    .from("postmortems")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  if (error) throw error;

  return data;
}

// Update an existing postmortem
export async function updatePostmortem(
  client: UserSupabaseClient,
  id: string,
  input: UpdatePostmortemInput
) {
  const updates = {
    ...input,
    updated_at: new Date().toISOString()
  };

  const { data, error } = await client
    .from("postmortems")
    .update(updates)
    .eq("id", id)
    .select("*")
    .maybeSingle();

  if (error) throw error;

  return data;
}
