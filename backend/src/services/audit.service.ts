import type { UserSupabaseClient } from "../config/supabase.js";

// The backend never writes audit entries (decision A7). They are written by
// the database itself, in the same transaction as the action:
// - workflow functions (approvals, playbook runs, AI analyses, recovery
//   checks), migration 000700;
// - triggers for incidents, postmortems, playbooks, integrations and role
//   changes, migration 000800.
// Clients have no INSERT permission on audit_logs (migration 000500).

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