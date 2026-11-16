import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import {
  supabaseMocks,
  supabaseModuleFactory,
  mockValidUser,
  TEST_TOKEN
} from "./helpers/mock-supabase-module.js";
import { createMockUserClient, callsFor } from "./helpers/supabase-mock.js";
import { testConfig } from "./helpers/config.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

// GET /api/incidents/:id/recommendation (mobile S17).
const INCIDENT_ID = "99999999-9999-4999-8999-999999999991";
const PATH = `/api/incidents/${INCIDENT_ID}/recommendation`;
const analysis = { id: "a1", incident_id: INCIDENT_ID, recommended_action: "restart", root_cause: "rc" };
const playbook = { id: "p1", name: "Restart sample-app", description: null, action_type: "restart" };

describe("GET /api/incidents/:id/recommendation", () => {
  const app = createApp(testConfig());

  it("requires authentication", async () => {
    const res = await request(app).get(PATH);
    expect(res.status).toBe(401);
  });

  it("returns the latest analysis, the playbooks for its action and the other enabled ones (user's client, RLS)", async () => {
    mockValidUser();
    const other = { id: "p2", name: "Open breaker", description: null, action_type: "circuit_breaker" };
    const { client, calls } = createMockUserClient({
      ai_analyses: { data: [analysis] },
      playbooks: { data: [playbook, other] }
    });
    supabaseMocks.createUserSupabaseClient.mockReturnValue(client);

    const res = await request(app).get(PATH).set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ analysis, playbooks: [playbook], other_playbooks: [other] });
    const playbookFilters = callsFor(calls, "playbooks", "eq").map((c) => c.args);
    expect(playbookFilters).toEqual([["enabled", true]]);
  });

  it("no analysis yet -> analysis null; every enabled playbook is an option", async () => {
    mockValidUser();
    const { client } = createMockUserClient({ ai_analyses: { data: [] }, playbooks: { data: [playbook] } });
    supabaseMocks.createUserSupabaseClient.mockReturnValue(client);

    const res = await request(app).get(PATH).set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ analysis: null, playbooks: [], other_playbooks: [playbook] });
  });

  it("invalid id -> 400", async () => {
    mockValidUser();
    supabaseMocks.createUserSupabaseClient.mockReturnValue(createMockUserClient().client);

    const res = await request(app).get("/api/incidents/nope/recommendation").set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(400);
  });
});

describe("GET /api/incidents/:id/recovery-checks", () => {
  const app = createApp(testConfig());

  it("returns the incident's recovery checks through the user's client", async () => {
    mockValidUser();
    const check = { id: "rc1", incident_id: INCIDENT_ID, status: "healthy" };
    const { client, calls } = createMockUserClient({ recovery_checks: { data: [check] } });
    supabaseMocks.createUserSupabaseClient.mockReturnValue(client);

    const res = await request(app)
      .get(`/api/incidents/${INCIDENT_ID}/recovery-checks`)
      .set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([check]);
    expect(callsFor(calls, "recovery_checks", "eq")[0]?.args).toEqual(["incident_id", INCIDENT_ID]);
  });
});
