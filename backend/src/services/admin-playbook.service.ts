import type { UserSupabaseClient } from "../config/supabase.js";

export interface CreatePlaybookInput {
  name: string;
  description?: string;
  action_type: string;
  configuration?: Record<string, unknown>;
  enabled?: boolean;
  requires_approval?: boolean;
}

export interface UpdatePlaybookInput {
  name?: string;
  description?: string;
  action_type?: string;
  configuration?: Record<string, unknown>;
  enabled?: boolean;
  requires_approval?: boolean;
}

export async function getAllPlaybooks(client: UserSupabaseClient) {
  const { data, error } = await client
    .from("playbooks")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) throw error;

  return data;
}

export async function createPlaybook(
  client: UserSupabaseClient,
  input: CreatePlaybookInput
) {
  const { data, error } = await client
    .from("playbooks")
    .insert({
      name: input.name,
      description: input.description ?? null,
      action_type: input.action_type,
      configuration: input.configuration ?? {},
      enabled: input.enabled ?? false,
      requires_approval: input.requires_approval ?? true
    })
    .select("*")
    .single();

  if (error) throw error;

  return data;
}

export async function updatePlaybook(
  client: UserSupabaseClient,
  id: string,
  input: UpdatePlaybookInput
) {
  const { data, error } = await client
    .from("playbooks")
    .update({
      ...input,
      updated_at: new Date().toISOString()
    })
    .eq("id", id)
    .select("*")
    .maybeSingle();

  if (error) throw error;

  return data;
}

export async function deletePlaybook(
  client: UserSupabaseClient,
  id: string
) {
  const { error } = await client
    .from("playbooks")
    .delete()
    .eq("id", id);

  if (error) throw error;

  return { success: true };
}