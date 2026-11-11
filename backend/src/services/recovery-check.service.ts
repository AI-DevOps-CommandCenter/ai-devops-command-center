import type { UserSupabaseClient } from "../config/supabase.js";

// Recovery checks after a remediation (BD-3, contract B.3).
// The database function validates the references and the status, redacts the
// details and writes the audit log and the incident timeline entry.

export const RECOVERY_CHECK_STATUSES = ["pending", "healthy", "unhealthy", "failed"] as const;
export type RecoveryCheckStatus = (typeof RECOVERY_CHECK_STATUSES)[number];

export interface RecordRecoveryCheckInput {
  incident_id: string;
  playbook_run_id: string;
  status: RecoveryCheckStatus;
  check_type?: string | null;
  details?: Record<string, unknown>;
}

// Automation identity (or admin/operator) only.
// rpc: record_recovery_check(p_incident_id, p_playbook_run_id, p_status, p_check_type, p_details)
//   DC404 incident not found; DC422 run does not belong to the incident or
//   details too large; 23514 invalid status. Returns the new recovery_checks.id.
export async function recordRecoveryCheck(
  client: UserSupabaseClient,
  input: RecordRecoveryCheckInput
): Promise<string> {
  const { data, error } = await client.rpc("record_recovery_check", {
    p_incident_id: input.incident_id,
    p_playbook_run_id: input.playbook_run_id,
    p_status: input.status,
    p_check_type: input.check_type ?? null,
    p_details: input.details ?? {}
  });

  if (error) throw error;
  if (typeof data !== "string") {
    throw new Error("record_recovery_check returned no id.");
  }
  return data;
}
