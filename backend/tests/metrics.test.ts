import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import {
  supabaseModuleFactory,
  mockValidUser,
  TEST_TOKEN
} from "./helpers/mock-supabase-module.js";
import { testConfig } from "./helpers/config.js";
import {
  createPrometheusClient,
  MetricsUnavailableError,
  type PrometheusClient
} from "../src/services/metrics.service.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

// Fake Prometheus: answers by matching a fragment of the PromQL.
function fakeProm(opts: { services?: string[]; fail?: boolean } = {}) {
  const services = opts.services ?? ["sample-app", "loki"];
  const queries: string[] = [];
  const client: PrometheusClient = {
    async query(promql) {
      queries.push(promql);
      if (opts.fail) throw new MetricsUnavailableError("Prometheus is not reachable.");
      if (promql.startsWith("max by (service) (up{")) {
        const s = promql.match(/service="([^"]+)"/)?.[1];
        return services.includes(s!) ? [{ metric: { service: s! }, value: 1 }] : [];
      }
      if (promql === "max by (service) (up)") {
        return services.map((s) => ({ metric: { service: s }, value: s === "loki" ? 0 : 1 }));
      }
      if (promql.includes("sum by (service)")) return [{ metric: { service: "sample-app" }, value: 0.25 }];
      if (promql.includes("process_cpu")) return [{ metric: {}, value: 3.5 }];
      if (promql.includes("histogram_quantile")) return [{ metric: {}, value: NaN }];
      return [{ metric: {}, value: 0.01 }];
    },
    async queryRange(promql) {
      queries.push(`range:${promql}`);
      return [{ metric: {}, values: [[1000, 0.01], [1060, 0.02]] }];
    }
  };
  return { client, queries };
}

const auth = { Authorization: `Bearer ${TEST_TOKEN}` };

describe("GET /api/metrics", () => {
  it("requires authentication", async () => {
    const app = createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: fakeProm().client });
    const res = await request(app).get("/api/metrics/services");
    expect(res.status).toBe(401);
  });

  it("answers 503 when Prometheus is not configured", async () => {
    mockValidUser();
    const app = createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: null });
    const res = await request(app).get("/api/metrics/services").set(auth);
    expect(res.status).toBe(503);
  });

  it("lists service health with status from up and the error rate", async () => {
    mockValidUser();
    const app = createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: fakeProm().client });
    const res = await request(app).get("/api/metrics/services").set(auth);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([
      { service: "loki", up: false, error_rate: null, status: "down" },
      { service: "sample-app", up: true, error_rate: 0.25, status: "warning" }
    ]);
  });

  it("returns current values and series for one service", async () => {
    mockValidUser();
    const { client, queries } = fakeProm();
    const app = createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: client });
    const res = await request(app).get("/api/metrics/services/sample-app?window=30").set(auth);
    expect(res.status).toBe(200);
    expect(res.body.data.service).toBe("sample-app");
    expect(res.body.data.window_minutes).toBe(30);
    expect(res.body.data.cpu_percent.current).toBe(3.5);
    expect(res.body.data.latency_p95_seconds.current).toBeNull(); // NaN -> null
    expect(res.body.data.error_rate.points).toEqual([{ t: 1000, v: 0.01 }, { t: 1060, v: 0.02 }]);
    expect(queries.every((q) => !q.includes("service=") || q.includes('service="sample-app"'))).toBe(true);
  });

  it("rejects service names that could change the PromQL", async () => {
    mockValidUser();
    const { client, queries } = fakeProm();
    const app = createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: client });
    const res = await request(app)
      .get(`/api/metrics/services/${encodeURIComponent('x"} or up{a="')}`)
      .set(auth);
    expect(res.status).toBe(400);
    expect(queries).toHaveLength(0);
  });

  it("rejects an out-of-range window", async () => {
    mockValidUser();
    const app = createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: fakeProm().client });
    const res = await request(app).get("/api/metrics/services/sample-app?window=5").set(auth);
    expect(res.status).toBe(400);
  });

  it("answers 404 for a service Prometheus does not know", async () => {
    mockValidUser();
    const app = createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: fakeProm().client });
    const res = await request(app).get("/api/metrics/services/payments-api").set(auth);
    expect(res.status).toBe(404);
  });

  it("answers 503 when Prometheus is down", async () => {
    mockValidUser();
    const app = createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: fakeProm({ fail: true }).client });
    const res = await request(app).get("/api/metrics/services").set(auth);
    expect(res.status).toBe(503);
    expect(res.body.message).toBe("Prometheus is not reachable.");
  });
});

describe("createPrometheusClient", () => {
  it("encodes the query and parses an instant vector", async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      expect(String(url)).toContain("/api/v1/query?query=up%7Bservice%3D%22a%22%7D");
      return new Response(JSON.stringify({ status: "success", data: { result: [{ metric: { service: "a" }, value: [1, "1"] }] } }));
    });
    const client = createPrometheusClient("http://prom:9090/", fetchImpl as unknown as typeof fetch);
    await expect(client.query('up{service="a"}')).resolves.toEqual([{ metric: { service: "a" }, value: 1 }]);
  });

  it("turns network and query errors into MetricsUnavailableError", async () => {
    const down = createPrometheusClient("http://prom:9090", (async () => { throw new Error("ECONNREFUSED"); }) as unknown as typeof fetch);
    await expect(down.query("up")).rejects.toBeInstanceOf(MetricsUnavailableError);
    const bad = createPrometheusClient("http://prom:9090", (async () =>
      new Response(JSON.stringify({ status: "error" }), { status: 400 })) as unknown as typeof fetch);
    await expect(bad.query("up")).rejects.toBeInstanceOf(MetricsUnavailableError);
  });
});
