import type { UserSupabaseClient } from "../config/supabase.js";

// Dashboard statistics structure
export interface DashboardSummary {
  total: number;
  open: number;
  investigating: number;
  awaiting_approval: number;
  remediating: number;
  resolved: number;
  critical: number;
}

// Retrieve dashboard statistics
export async function getDashboardSummary(
  client: UserSupabaseClient
) {
  // Run all database count queries simultaneously
  const [
    totalResult,
    openResult,
    investigatingResult,
    awaitingApprovalResult,
    remediatingResult,
    resolvedResult,
    criticalResult
  ] = await Promise.all([
    client.from("incidents")
      .select("id", { count: "exact", head: true }),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("status", "open"),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("status", "investigating"),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("status", "awaiting_approval"),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("status", "remediating"),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("status", "resolved"),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("severity", "critical")
  ]);

  // Check whether any database query failed
  const results = [
    totalResult,
    openResult,
    investigatingResult,
    awaitingApprovalResult,
    remediatingResult,
    resolvedResult,
    criticalResult
  ];

  const failedResult = results.find(
    (result) => result.error !== null
  );

  if (failedResult?.error) {
    return {
      data: null,
      error: failedResult.error
    };
  }

  // Build dashboard summary
  const data: DashboardSummary = {
    total: totalResult.count ?? 0,
    open: openResult.count ?? 0,
    investigating: investigatingResult.count ?? 0,
    awaiting_approval: awaitingApprovalResult.count ?? 0,
    remediating: remediatingResult.count ?? 0,
    resolved: resolvedResult.count ?? 0,
    critical: criticalResult.count ?? 0
  };

  return {
    data,
    error: null
  };
}