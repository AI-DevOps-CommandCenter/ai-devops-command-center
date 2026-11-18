import type { UserSupabaseClient } from "../config/supabase.js";

// Local releases (migration 20261118000400). Written by
// monitoring/scripts/release.sh, read by n8n workflow 04. Both database
// functions accept only the automation identity.

export const DEPLOYMENT_STATUSES = ["success", "failed"] as const;
export type DeploymentStatus = (typeof DEPLOYMENT_STATUSES)[number];

export const SERVICE_NAME_PATTERN = /^[A-Za-z0-9_.:-]{1,100}$/;
export const VERSION_PATTERN = /^[A-Za-z0-9_.+-]{1,64}$/;
export const PROVIDER_PATTERN = /^[a-z0-9_-]{1,30}$/;

export interface RecordDeploymentInput {
  service_name: string;
  version: string;
  status: DeploymentStatus;
  provider: string;
}

export interface RecentDeployment {
  id: string;
  service_name: string;
  version: string;
  provider: string | null;
  status: string;
  completed_at: string;
}

export async function recordDeployment(
  client: UserSupabaseClient,
  input: RecordDeploymentInput
): Promise<string> {
  const { data, error } = await client.rpc("record_deployment", {
    p_service_name: input.service_name,
    p_version: input.version,
    p_status: input.status,
    p_provider: input.provider
  });

  if (error) throw error;
  if (typeof data !== "string") {
    throw new Error("record_deployment returned no id.");
  }
  return data;
}

export async function listRecentDeployments(
  client: UserSupabaseClient,
  serviceName: string,
  since: string,
  until: string
): Promise<RecentDeployment[]> {
  const { data, error } = await client.rpc("list_recent_deployments", {
    p_service_name: serviceName,
    p_since: since,
    p_until: until
  });

  if (error) throw error;
  return Array.isArray(data) ? (data as RecentDeployment[]) : [];
}
