import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import {
  supabaseMocks,
  supabaseModuleFactory,
  mockValidUser,
  TEST_TOKEN,
  TEST_USER
} from "./helpers/mock-supabase-module.js";
import { createMockUserClient, callsFor } from "./helpers/supabase-mock.js";
import { testConfig } from "./helpers/config.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

// Contract tests: these pin the existing behaviour of POST /api/incidents so
// the P1 refactor (app split, security middleware) cannot silently change it.
describe("POST /api/incidents (existing contract preserved)", () => {
  const app = createApp(testConfig());

  const validBody = {
    title: "  Checkout latency  ",
    service_name: " Payment Service ",
    severity: "high",
    description: "p95 above threshold"
  };

  const createdRow = {
    id: "22222222-2222-4222-8222-222222222222",
    title: "Checkout latency",
    service_name: "Payment Service",
    severity: "high",
    status: "open"
  };

  it("requires authentication", async () => {
    const res = await request(app).post("/api/incidents").send(validBody);

    expect(res.status).toBe(401);
  });

  it("keeps the existing validation message", async () => {
    mockValidUser();
    supabaseMocks.createUserSupabaseClient.mockReturnValue(
      createMockUserClient().client
    );

    const res = await request(app)
      .post("/api/incidents")
      .set("Authorization", `Bearer ${TEST_TOKEN}`)
      .send({ title: "x", severity: "not-a-severity" });

    expect(res.status).toBe(400);
    expect(res.body).toEqual({
      success: false,
      message: "Title, service name and a valid severity are required."
    });
  });

  it("creates the incident through the user's client; the database audits it", async () => {
    mockValidUser();
    const { client, calls } = createMockUserClient({
      incidents: { data: createdRow, error: null }
    });
    supabaseMocks.createUserSupabaseClient.mockReturnValue(client);

    const res = await request(app)
      .post("/api/incidents")
      .set("Authorization", `Bearer ${TEST_TOKEN}`)
      .send(validBody);

    expect(res.status).toBe(201);
    expect(res.body).toEqual({
      success: true,
      message: "Incident created successfully.",
      data: createdRow
    });

    const [insert] = callsFor(calls, "incidents", "insert");
    expect(insert?.args[0]).toMatchObject({
      title: "Checkout latency",
      service_name: "Payment Service",
      severity: "high",
      status: "open",
      source: "manual",
      created_by: TEST_USER.id
    });

    // A7 / migration 000800: the INCIDENT_CREATED audit entry is written by a
    // database trigger in the same transaction, so the backend must not write
    // one itself (it has no INSERT permission on audit_logs, and a second
    // entry would be a duplicate).
    expect(calls.some((call) => call.table === "audit_logs")).toBe(false);
  });

  it("does not depend on an audit write (previously best-effort, now done by the database)", async () => {
    mockValidUser();
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const { client } = createMockUserClient({
      incidents: { data: createdRow, error: null },
      audit_logs: { data: null, error: { message: "insert denied" } }
    });
    supabaseMocks.createUserSupabaseClient.mockReturnValue(client);

    const res = await request(app)
      .post("/api/incidents")
      .set("Authorization", `Bearer ${TEST_TOKEN}`)
      .send(validBody);

    expect(res.status).toBe(201);
    expect(errorSpy).not.toHaveBeenCalled();
  });
});
