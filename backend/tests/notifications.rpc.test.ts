import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import {
  supabaseMocks,
  supabaseModuleFactory,
  mockValidUser,
  TEST_TOKEN
} from "./helpers/mock-supabase-module.js";

import {
  createMockUserClient,
  callsFor,
  type RecordedCall
} from "./helpers/supabase-mock.js";

import { testConfig } from "./helpers/config.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

const app = createApp(testConfig(), { machine: null });

const NOTIFICATION_ID = "33333333-3333-4333-8333-333333333331";
const DEVICE_TOKEN_ID = "33333333-3333-4333-8333-333333333332";

const notificationRow = {
  id: NOTIFICATION_ID,
  user_id: "11111111-1111-4111-8111-111111111111",
  title: "Incident detected",
  message: "High CPU usage detected.",
  channel: "in_app",
  status: "sent",
  created_at: "2026-11-10T10:00:00Z",
  read_at: null
};

function useClient(results: Parameters<typeof createMockUserClient>[0] = {}) {
  mockValidUser();

  const mock = createMockUserClient(results);
  supabaseMocks.createUserSupabaseClient.mockReturnValue(mock.client);

  return mock;
}

function get(path: string) {
  return request(app)
    .get(path)
    .set("Authorization", `Bearer ${TEST_TOKEN}`);
}

function post(path: string, body: unknown) {
  return request(app)
    .post(path)
    .set("Authorization", `Bearer ${TEST_TOKEN}`)
    .send(body as object);
}

function patch(path: string, body: unknown = {}) {
  return request(app)
    .patch(path)
    .set("Authorization", `Bearer ${TEST_TOKEN}`)
    .send(body as object);
}

function remove(path: string, body: unknown) {
  return request(app)
    .delete(path)
    .set("Authorization", `Bearer ${TEST_TOKEN}`)
    .send(body as object);
}

function expectNoDirectWrites(calls: RecordedCall[]) {
  const writes = calls.filter((call) =>
    ["insert", "update", "upsert", "delete"].includes(call.method)
  );

  expect(writes).toEqual([]);
}

describe("GET /api/notifications", () => {
  it("requires authentication", async () => {
    const res = await request(app).get("/api/notifications");

    expect(res.status).toBe(401);
  });

  it("returns the caller's notification inbox", async () => {
    const { calls } = useClient({
      notifications: {
        data: [notificationRow],
        count: 1
      }
    });

    const res = await get("/api/notifications");

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toEqual([notificationRow]);
    expect(res.body.count).toBe(1);

    expect(calls.some((call) =>
      call.table === "notifications" && call.method === "select"
    )).toBe(true);

    expectNoDirectWrites(calls);
  });

  it("rejects invalid pagination values", async () => {
    const { calls } = useClient({});

    const res = await get("/api/notifications?limit=500");

    expect(res.status).toBe(400);
    expect(callsFor(calls, "notifications", "select")).toHaveLength(0);
  });
});

describe("PATCH /api/notifications/:id/read", () => {
  it("requires authentication", async () => {
    const res = await request(app)
      .patch(`/api/notifications/${NOTIFICATION_ID}/read`);

    expect(res.status).toBe(401);
  });

  it("marks a notification as read through the database function", async () => {
    const { calls } = useClient({
      "rpc:mark_notification_read": {
        data: true
      }
    });

    const res = await patch(
      `/api/notifications/${NOTIFICATION_ID}/read`
    );

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    expect(callsFor(calls, "rpc:mark_notification_read", "rpc")[0]?.args[0])
      .toEqual({
        p_notification_id: NOTIFICATION_ID
      });

    expectNoDirectWrites(calls);
  });

  it("rejects an invalid notification ID", async () => {
    const { calls } = useClient({});

    const res = await patch("/api/notifications/not-a-uuid/read");

    expect(res.status).toBe(400);
    expect(callsFor(calls, "rpc:mark_notification_read", "rpc"))
      .toHaveLength(0);
  });

  it("returns 404 when the notification is not accessible", async () => {
    useClient({
      "rpc:mark_notification_read": {
        error: {
          code: "DC404",
          message: "Notification not found."
        }
      }
    });

    const res = await patch(
      `/api/notifications/${NOTIFICATION_ID}/read`
    );

    expect(res.status).toBe(404);
    expect(res.body.message).toBe("Notification not found.");
  });
});

describe("POST /api/device-tokens", () => {
  const validToken = "test-device-token-123456";

  it("requires authentication", async () => {
    const res = await request(app)
      .post("/api/device-tokens")
      .send({
        device_token: validToken,
        platform: "android"
      });

    expect(res.status).toBe(401);
  });

  it("registers a device token through the database function", async () => {
    const { calls } = useClient({
      "rpc:register_device_token": {
        data: DEVICE_TOKEN_ID
      }
    });

    const res = await post("/api/device-tokens", {
      device_token: validToken,
      platform: "android"
    });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);

    expect(callsFor(calls, "rpc:register_device_token", "rpc")[0]?.args[0])
      .toEqual({
        p_device_token: validToken,
        p_platform: "android"
      });

    expectNoDirectWrites(calls);
  });

  it("rejects an unsupported platform", async () => {
    const { calls } = useClient({});

    const res = await post("/api/device-tokens", {
      device_token: validToken,
      platform: "windows"
    });

    expect(res.status).toBe(400);
    expect(callsFor(calls, "rpc:register_device_token", "rpc"))
      .toHaveLength(0);
  });
});

describe("DELETE /api/device-tokens", () => {
  const validToken = "test-device-token-123456";

  it("requires authentication", async () => {
    const res = await request(app)
      .delete("/api/device-tokens")
      .send({ device_token: validToken });

    expect(res.status).toBe(401);
  });

  it("unregisters a device token through the database function", async () => {
    const { calls } = useClient({
      "rpc:unregister_device_token": {
        data: true
      }
    });

    const res = await remove("/api/device-tokens", {
      device_token: validToken
    });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    expect(callsFor(calls, "rpc:unregister_device_token", "rpc")[0]?.args[0])
      .toEqual({
        p_device_token: validToken
      });

    expectNoDirectWrites(calls);
  });
});