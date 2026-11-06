import type { UserSupabaseClient } from "../config/supabase.js";

export type PlaybookActionType =
  | "restart"
  | "circuit_breaker"
  | "rollback"
  | "scale";

export interface CreatePlaybookInput {
  name: string;
  description?: string;
  action_type: PlaybookActionType;
  configuration?: Record<string, unknown>;
  enabled?: boolean;
  requires_approval?: boolean;
}

export interface UpdatePlaybookInput {
  name?: string;
  description?: string | null;
  action_type?: PlaybookActionType;
  configuration?: Record<string, unknown>;
  enabled?: boolean;
  requires_approval?: boolean;
}

// GET all playbooks
export async function getAllPlaybooks(
  client: UserSupabaseClient
) {
  const { data, error } = await client
    .from("playbooks")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) throw error;

  return data;
}

// CREATE a playbook
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

// UPDATE a playbook
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

// DELETE a playbook
export async function deletePlaybook(
  client: UserSupabaseClient,
  id: string
) {
  const { data, error } = await client
    .from("playbooks")
    .delete()
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) throw error;

  if (!data) {
    return null;
  }

  return { success: true };
}
