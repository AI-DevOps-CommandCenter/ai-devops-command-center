import type { UserSupabaseClient } from "../config/supabase.js";

export interface CreateAuditLogInput {
  action: string;
  entity_type?: string;
  entity_id?: string;
  details?: Record<string, unknown>;
}

export async function createAuditLog(
  client: UserSupabaseClient,
  input: CreateAuditLogInput,
  actorId: string
) {
  const { error } = await client
    .from("audit_logs")
    .insert({
      actor_id: actorId,
      action: input.action,
      entity_type: input.entity_type ?? null,
      entity_id: input.entity_id ?? null,
      details: input.details ?? {}
    });

  if (error) {
    throw error;
  }

  return { success: true };
}
export interface AuditLogFilters {
  action?: string;
  entity_type?: string;
  limit?: number;
  offset?: number;
}

export async function getAuditLogs(
  client: UserSupabaseClient,
  filters: AuditLogFilters = {}
) {
  const limit = filters.limit ?? 20;
  const offset = filters.offset ?? 0;

  let query = client
    .from("audit_logs")
    .select("*")
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (filters.action) {
    query = query.eq("action", filters.action);
  }

  if (filters.entity_type) {
    query = query.eq("entity_type", filters.entity_type);
  }

  const { data, error } = await query;

  if (error) throw error;

  return data;
}