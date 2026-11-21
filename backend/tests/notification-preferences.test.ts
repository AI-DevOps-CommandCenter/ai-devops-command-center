import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseMocks, supabaseModuleFactory, mockValidUser, TEST_TOKEN } from "./helpers/mock-supabase-module.js";
import { createMockUserClient, callsFor, type RecordedCall } from "./helpers/supabase-mock.js";
import { testConfig } from "./helpers/config.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");
const { serverChannelStatus } = await import("../src/controllers/notification.controller.js");

const app = createApp(testConfig(), { machine: null, remediationDispatcher: null });
const auth = { Authorization: `Bearer ${TEST_TOKEN}` };

function useClient(results: Parameters<typeof createMockUserClient>[0] = {}) {
  mockValidUser();
  const mock = createMockUserClient(results);
  supabaseMocks.createUserSupabaseClient.mockReturnValue(mock.client);
  return mock;
}

const noDirectWrites = (calls: RecordedCall[]) =>
  expect(calls.filter((c) => ["insert", "update", "upsert", "delete"].includes(c.method))).toEqual([]);

describe("GET /api/notifications/preferences", () => {
  it("requires authentication", async () => {
    expect((await request(app).get("/api/notifications/preferences")).status).toBe(401);
  });

  it("returns the caller's settings through the database function", async () => {
    const { calls } = useClient({
      "rpc:get_notification_preferences": { data: [{ push_enabled: false, email_enabled: true, updated_at: "2026-11-18T08:00:00Z" }] }
    });

    const res = await request(app).get("/api/notifications/preferences").set(auth);

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ push_enabled: false, email_enabled: true, in_app_enabled: true,
      updated_at: "2026-11-18T08:00:00Z" });
    expect(res.body.data.server_channels).toEqual(expect.objectContaining({ push: false }));
    expect(callsFor(calls, "rpc:get_notification_preferences", "rpc")).toHaveLength(1);
    noDirectWrites(calls);
  });

  it("falls back to the defaults when the function returns no row", async () => {
    useClient({ "rpc:get_notification_preferences": { data: [] } });
    const res = await request(app).get("/api/notifications/preferences").set(auth);
    expect(res.body.data).toMatchObject({ push_enabled: true, email_enabled: false, updated_at: null });
  });

  it("is not captured by the /:id routes", async () => {
    useClient({ "rpc:get_notification_preferences": { data: [] } });
    expect((await request(app).get("/api/notifications/preferences").set(auth)).status).toBe(200);
  });
});

describe("PUT /api/notifications/preferences", () => {
  it("saves both flags with set_notification_preferences", async () => {
    const { calls } = useClient({
      "rpc:set_notification_preferences": { data: [{ push_enabled: true, email_enabled: true, updated_at: "2026-11-18T09:00:00Z" }] }
    });

    const res = await request(app).put("/api/notifications/preferences").set(auth).send({ push_enabled: true, email_enabled: true });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ push_enabled: true, email_enabled: true });
    expect(callsFor(calls, "rpc:set_notification_preferences", "rpc")[0]?.args[0]).toEqual({
      p_push_enabled: true, p_email_enabled: true });
    noDirectWrites(calls);
  });

  it.each([{}, { push_enabled: true }, { push_enabled: "yes", email_enabled: false }, { push_enabled: 1, email_enabled: 0 }])(
    "rejects %j with 400", async (body) => {
      const { calls } = useClient();
      const res = await request(app).put("/api/notifications/preferences").set(auth).send(body);
      expect(res.status).toBe(400);
      expect(callsFor(calls, "rpc:set_notification_preferences", "rpc")).toHaveLength(0);
    });

  it("maps a database role error to 403", async () => {
    useClient({ "rpc:set_notification_preferences": { error: { code: "DC403", message: "Not allowed." } } });
    const res = await request(app).put("/api/notifications/preferences").set(auth).send({ push_enabled: true, email_enabled: false });
    expect(res.status).toBe(403);
  });
});

describe("serverChannelStatus", () => {
  it("reports which team channels the backend can send to", () => {
    expect(serverChannelStatus({})).toEqual({ push: false, email: false, slack: false, discord: false });
    expect(serverChannelStatus({ SLACK_WEBHOOK_URL: "https://hooks.slack.com/services/T000/B000/XXXX" }).slack).toBe(true);
    expect(serverChannelStatus({ SLACK_WEBHOOK_URL: "http://not-slack" })).toEqual({ push: false, email: false, slack: false, discord: false });
  });
});
