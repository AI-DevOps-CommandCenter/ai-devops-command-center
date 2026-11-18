import { describe, expect, it } from "vitest";
import { getIncidents, NOT_TEST_ENVIRONMENT_FILTER } from "../src/services/incident.service.js";
import { getDashboardSummary } from "../src/services/dashboard.service.js";

// Records the PostgREST calls made on a query; resolves to an empty result.
function fakeClient() {
  const queries: Array<Array<[string, unknown[]]>> = [];
  const client = {
    from(table: string) {
      const calls: Array<[string, unknown[]]> = [["from", [table]]];
      queries.push(calls);
      const builder: Record<string, unknown> = {};
      for (const m of ["select", "order", "range", "eq", "or"]) {
        builder[m] = (...args: unknown[]) => {
          calls.push([m, args]);
          return builder;
        };
      }
      builder.then = (resolve: (v: unknown) => unknown) => resolve({ data: [], error: null, count: 0 });
      return builder;
    }
  };
  return { client: client as never, queries };
}

const orFilters = (calls: Array<[string, unknown[]]>) => calls.filter(([m]) => m === "or").map(([, a]) => a[0]);

describe("test incidents (environment = 'test') are hidden", () => {
  it("the filter keeps NULL environments and drops 'test'", () => {
    expect(NOT_TEST_ENVIRONMENT_FILTER).toBe("environment.is.null,environment.neq.test");
  });

  it("getIncidents hides them by default", async () => {
    const { client, queries } = fakeClient();
    await getIncidents(client, { status: "resolved" });
    expect(orFilters(queries[0])).toEqual([NOT_TEST_ENVIRONMENT_FILTER]);
  });

  it("getIncidents shows them with include_test", async () => {
    const { client, queries } = fakeClient();
    await getIncidents(client, { include_test: true });
    expect(orFilters(queries[0])).toEqual([]);
  });

  it("every dashboard count leaves them out", async () => {
    const { client, queries } = fakeClient();
    await getDashboardSummary(client);
    const incidentQueries = queries.filter((q) => q[0][1][0] === "incidents");
    expect(incidentQueries.length).toBe(8);
    for (const q of incidentQueries) expect(orFilters(q)).toEqual([NOT_TEST_ENVIRONMENT_FILTER]);
  });
});
