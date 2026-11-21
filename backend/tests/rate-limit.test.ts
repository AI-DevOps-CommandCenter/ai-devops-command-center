import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseModuleFactory } from "./helpers/mock-supabase-module.js";
import { testConfig } from "./helpers/config.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

describe("API rate limiting", () => {
  it("returns JSON 429 after the configured limit", async () => {
    const app = createApp(testConfig({ rateLimitMax: 2 }));

    await request(app).get("/api/me");
    await request(app).get("/api/me");
    const limited = await request(app).get("/api/me");

    expect(limited.status).toBe(429);
    expect(limited.body).toEqual({
      success: false,
      message: "Too many requests. Please try again later."
    });
    expect(limited.headers["ratelimit-policy"]).toBeDefined();
  });

  it("does not rate-limit the root route", async () => {
    const app = createApp(testConfig({ rateLimitMax: 1 }));

    await request(app).get("/");
    await request(app).get("/");
    const res = await request(app).get("/");

    expect(res.status).toBe(200);
  });
});
