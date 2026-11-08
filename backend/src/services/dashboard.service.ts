import type { UserSupabaseClient } from "../config/supabase.js";

// Dashboard statistics structure
export interface DashboardSummary {
  total: number;
  open: number;
  investigating: number;
  identified: number;
  mitigating: number;
  resolved: number;
  closed: number;
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
    identifiedResult,
    mitigatingResult,
    resolvedResult,
    closedResult,
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
      .eq("status", "identified"),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("status", "mitigating"),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("status", "resolved"),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("status", "closed"),

    client.from("incidents")
      .select("id", { count: "exact", head: true })
      .eq("severity", "critical")
  ]);

  // Check whether any database query failed
  const results = [
    totalResult,
    openResult,
    investigatingResult,
    identifiedResult,
    mitigatingResult,
    resolvedResult,
    closedResult,
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
    identified: identifiedResult.count ?? 0,
    mitigating: mitigatingResult.count ?? 0,
    resolved: resolvedResult.count ?? 0,
    closed: closedResult.count ?? 0,
    critical: criticalResult.count ?? 0
  };

  return {
    data,
    error: null
  };
}