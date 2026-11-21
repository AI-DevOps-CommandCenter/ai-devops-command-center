import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseModuleFactory } from "./helpers/mock-supabase-module.js";
import { testConfig } from "./helpers/config.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

describe("application basics", () => {
  const app = createApp(testConfig());

  it("keeps the root health message", async () => {
    const res = await request(app).get("/");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      message: "AI-Powered Mobile DevOps Command Center API is running!"
    });
  });

  it("returns JSON 404 for unknown routes", async () => {
    const res = await request(app).get("/api/does-not-exist");

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ success: false, message: "Route not found." });
  });

  it("returns JSON 400 for malformed JSON bodies", async () => {
    const res = await request(app)
      .post("/api/incidents")
      .set("Content-Type", "application/json")
      .send("{ not valid json");

    expect(res.status).toBe(400);
    expect(res.body).toEqual({
      success: false,
      message: "Malformed JSON request body."
    });
  });
});

describe("security headers (Helmet)", () => {
  const app = createApp(testConfig());

  it("sets standard security headers and hides the framework", async () => {
    const res = await request(app).get("/");

    expect(res.headers["x-content-type-options"]).toBe("nosniff");
    expect(res.headers["x-frame-options"]).toBe("SAMEORIGIN");
    expect(res.headers["strict-transport-security"]).toBeDefined();
    expect(res.headers["x-powered-by"]).toBeUndefined();
  });
});

describe("restricted CORS", () => {
  const app = createApp(testConfig());

  it("allows an origin on the allow-list", async () => {
    const res = await request(app)
      .get("/")
      .set("Origin", "https://allowed.example.test");

    expect(res.headers["access-control-allow-origin"]).toBe(
      "https://allowed.example.test"
    );
  });

  it("sends no CORS headers to other origins", async () => {
    const res = await request(app)
      .get("/")
      .set("Origin", "https://evil.example.test");

    expect(res.headers["access-control-allow-origin"]).toBeUndefined();
  });

  it("does not affect requests without an Origin header (mobile/native clients)", async () => {
    const res = await request(app).get("/");

    expect(res.status).toBe(200);
  });

  it("answers preflight requests for allowed origins", async () => {
    const res = await request(app)
      .options("/api/incidents")
      .set("Origin", "https://allowed.example.test")
      .set("Access-Control-Request-Method", "POST")
      .set("Access-Control-Request-Headers", "Authorization, Content-Type");

    expect(res.status).toBe(204);
    expect(res.headers["access-control-allow-origin"]).toBe(
      "https://allowed.example.test"
    );
    expect(res.headers["access-control-allow-headers"]).toContain("Authorization");
  });

  it("allows no cross-origin browser access when CORS_ORIGINS is empty", async () => {
    const closedApp = createApp(testConfig({ corsOrigins: [] }));
    const res = await request(closedApp)
      .get("/")
      .set("Origin", "https://allowed.example.test");

    expect(res.headers["access-control-allow-origin"]).toBeUndefined();
  });
});
