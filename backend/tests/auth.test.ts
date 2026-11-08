import { beforeEach, describe, expect, it, vi } from "vitest";
import express from "express";
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
const { authenticateToken, requireRole, extractBearerToken } = await import(
  "../src/middleware/auth.js"
);

describe("extractBearerToken", () => {
  it.each([
    [undefined, null],
    ["", null],
    ["Basic abc", null],
    ["Bearer", null],
    ["Bearer    ", null],
    ["Bearer abc.def.ghi", "abc.def.ghi"],
    ["bearer abc", "abc"],
    ["  Bearer   abc  ", "abc"]
  ])("parses %j as %j", (header, expected) => {
    expect(extractBearerToken(header)).toBe(expected);
  });
});

describe("authenticateToken (user JWT, decision D-002)", () => {
  const app = createApp(testConfig());

  beforeEach(() => {
    supabaseMocks.createUserSupabaseClient.mockReturnValue(
      createMockUserClient().client
    );
  });

  it("rejects requests without a token (unchanged contract)", async () => {
    const res = await request(app).get("/api/me");

    expect(res.status).toBe(401);
    expect(res.body).toEqual({
      success: false,
      message: "Authentication token is required."
    });
    expect(supabaseMocks.getUser).not.toHaveBeenCalled();
  });

  it("rejects non-Bearer schemes", async () => {
    const res = await request(app).get("/api/me").set("Authorization", "Basic abc");

    expect(res.status).toBe(401);
    expect(res.body.message).toBe("Authentication token is required.");
  });

  it("rejects invalid or expired tokens (unchanged contract)", async () => {
    supabaseMocks.getUser.mockResolvedValue({
      data: { user: null },
      error: { message: "invalid JWT" }
    });

    const res = await request(app)
      .get("/api/me")
      .set("Authorization", "Bearer bad-token");

    expect(res.status).toBe(401);
    expect(res.body).toEqual({
      success: false,
      message: "Invalid or expired token."
    });
  });

  it("returns 500 when token verification fails unexpectedly", async () => {
    supabaseMocks.getUser.mockRejectedValue(new Error("boom"));
    vi.spyOn(console, "error").mockImplementation(() => {});

    const res = await request(app)
      .get("/api/me")
      .set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(500);
    expect(res.body).toEqual({ success: false, message: "Authentication failed." });
  });

  it("verifies the token and creates a per-request client with the same JWT", async () => {
    mockValidUser();

    const res = await request(app)
      .get("/api/me")
      .set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      success: true,
      message: "Authentication successful!",
      user: { id: TEST_USER.id, email: TEST_USER.email }
    });
    expect(supabaseMocks.getUser).toHaveBeenCalledWith(TEST_TOKEN);
    expect(supabaseMocks.createUserSupabaseClient).toHaveBeenCalledWith(TEST_TOKEN);
  });
});

describe("requireRole (role read through the user's JWT client)", () => {
  function buildApp(profileResult: { data?: unknown; error?: unknown }) {
    const { client, calls } = createMockUserClient({ profiles: profileResult });
    supabaseMocks.createUserSupabaseClient.mockReturnValue(client);
    mockValidUser();

    const app = express();
    app.get("/admin-only", authenticateToken, requireRole("admin"), (req, res) => {
      res.json({ success: true, role: req.userRole });
    });

    return { app, calls };
  }

  it("allows a permitted role and exposes it on the request", async () => {
    const { app, calls } = buildApp({ data: { role: "admin" }, error: null });

    const res = await request(app)
      .get("/admin-only")
      .set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, role: "admin" });
    expect(callsFor(calls, "profiles", "eq")[0]?.args).toEqual(["id", TEST_USER.id]);
  });

  it("forbids other roles", async () => {
    const { app } = buildApp({ data: { role: "operator" }, error: null });

    const res = await request(app)
      .get("/admin-only")
      .set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(403);
    expect(res.body).toEqual({
      success: false,
      message: "You do not have permission to perform this action."
    });
  });

  it("forbids unknown role values", async () => {
    const { app } = buildApp({ data: { role: "automation" }, error: null });

    const res = await request(app)
      .get("/admin-only")
      .set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(403);
    expect(res.body.message).toBe("User profile or valid role not found.");
  });

  it("forbids users without a visible profile row", async () => {
    const { app } = buildApp({
      data: null,
      error: { code: "PGRST116", message: "0 rows" }
    });

    const res = await request(app)
      .get("/admin-only")
      .set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(403);
    expect(res.body.message).toBe("User profile or valid role not found.");
  });

  it("returns 500 when the profile cannot be read", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const { app } = buildApp({ data: null, error: { message: "rls denied" } });

    const res = await request(app)
      .get("/admin-only")
      .set("Authorization", `Bearer ${TEST_TOKEN}`);

    expect(res.status).toBe(500);
    expect(res.body).toEqual({
      success: false,
      message: "Unable to verify user permissions."
    });
  });

  it("requires authentication first", async () => {
    const app = express();
    app.get("/admin-only", requireRole("admin"), (_req, res) => {
      res.json({ success: true });
    });

    const res = await request(app).get("/admin-only");

    expect(res.status).toBe(401);
  });
});
