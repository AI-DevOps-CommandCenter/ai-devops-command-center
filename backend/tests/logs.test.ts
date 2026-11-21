import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseModuleFactory, mockValidUser, TEST_TOKEN } from "./helpers/mock-supabase-module.js";
import { testConfig } from "./helpers/config.js";
import { LogsUnavailableError, parseLogLine, type LokiClient } from "../src/services/logs.service.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");
const auth = { Authorization: `Bearer ${TEST_TOKEN}` };

function fakeLoki(fail = false) {
  const queries: string[] = [];
  const loki: LokiClient = {
    async queryRange(logql) {
      queries.push(logql);
      if (fail) throw new LogsUnavailableError("Loki is not reachable.");
      return [
        {
          stream: { service: "sample-app", level: "error" },
          values: [
            ["1794900000000000000", JSON.stringify({ level: "error", msg: "inventory call failed", logger: "app", exc_info: "Traceback ..." })],
            ["1794900060000000000", "plain text warning"]
          ]
        }
      ];
    }
  };
  return { loki, queries };
}

const app = (loki: LokiClient | null) =>
  createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: null, loki });

describe("GET /api/logs/services/:service", () => {
  it("requires authentication", async () => {
    const res = await request(app(fakeLoki().loki)).get("/api/logs/services/sample-app");
    expect(res.status).toBe(401);
  });

  it("answers 503 when Loki is not configured", async () => {
    mockValidUser();
    const res = await request(app(null)).get("/api/logs/services/sample-app").set(auth);
    expect(res.status).toBe(503);
  });

  it("returns newest lines first with the workflow 02 error filter", async () => {
    mockValidUser();
    const { loki, queries } = fakeLoki();
    const res = await request(app(loki)).get("/api/logs/services/sample-app?minutes=30").set(auth);
    expect(res.status).toBe(200);
    expect(queries[0]).toBe('{service="sample-app"} |~ "(?i)(error|exception|fatal|panic|critical|warn)"');
    expect(res.body.data.map((l: { message: string }) => l.message)).toEqual([
      "plain text warning",
      "inventory call failed\nTraceback ..."
    ]);
    expect(res.body.data[1]).toMatchObject({ level: "error", logger: "app" });
  });

  it("level=all drops the error filter", async () => {
    mockValidUser();
    const { loki, queries } = fakeLoki();
    await request(app(loki)).get("/api/logs/services/sample-app?level=all").set(auth);
    expect(queries[0]).toBe('{service="sample-app"}');
  });

  it("rejects unsafe service names and bad parameters without querying Loki", async () => {
    mockValidUser();
    const { loki, queries } = fakeLoki();
    const a = app(loki);
    expect((await request(a).get(`/api/logs/services/${encodeURIComponent('x"} |= "')}`).set(auth)).status).toBe(400);
    expect((await request(a).get("/api/logs/services/sample-app?minutes=0").set(auth)).status).toBe(400);
    expect((await request(a).get("/api/logs/services/sample-app?limit=9999").set(auth)).status).toBe(400);
    expect((await request(a).get("/api/logs/services/sample-app?level=debug").set(auth)).status).toBe(400);
    expect(queries).toHaveLength(0);
  });

  it("answers 503 when Loki is down", async () => {
    mockValidUser();
    const res = await request(app(fakeLoki(true).loki)).get("/api/logs/services/sample-app").set(auth);
    expect(res.status).toBe(503);
  });
});

describe("parseLogLine", () => {
  it("converts the nanosecond timestamp to ISO", () => {
    expect(parseLogLine("1794900000000000000", "x", {}).time).toBe(new Date(1794900000000).toISOString());
  });
});
