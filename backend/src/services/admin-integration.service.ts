import type { UserSupabaseClient } from "../config/supabase.js";

export interface CreateIntegrationInput {
  name: string;
  provider: string;
  is_active?: boolean;
  settings?: Record<string, unknown>;
}

export interface UpdateIntegrationInput {
  name?: string;
  provider?: string;
  is_active?: boolean;
  settings?: Record<string, unknown>;
}

export async function getAllIntegrations(
  client: UserSupabaseClient
) {
  const { data, error } = await client
    .from("integrations")
    .select("id, name, provider, is_active, created_by, created_at")
    .order("created_at", { ascending: false });

  if (error) throw error;

  return data;
}

export async function createIntegration(
  client: UserSupabaseClient,
  input: CreateIntegrationInput,
  userId: string
) {
  const { data, error } = await client
    .from("integrations")
    .insert({
      name: input.name,
      provider: input.provider,
      is_active: input.is_active ?? true,
      settings: input.settings ?? {},
      created_by: userId
    })
    .select("id, name, provider, is_active, created_by, created_at")
    .single();

  if (error) throw error;

  return data;
}

export async function updateIntegration(
  client: UserSupabaseClient,
  id: string,
  input: UpdateIntegrationInput
) {
  const { data, error } = await client
    .from("integrations")
    .update(input)
    .eq("id", id)
    .select("id, name, provider, is_active, created_by, created_at")
    .maybeSingle();

  if (error) throw error;

  return data;
}

export async function deleteIntegration(
  client: UserSupabaseClient,
  id: string
) {
  const { data, error } = await client
    .from("integrations")
    .delete()
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) throw error;

  return data;
}
