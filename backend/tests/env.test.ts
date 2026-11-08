import { describe, expect, it } from "vitest";

import {
  isPrivilegedSupabaseKey,
  loadSupabaseEnv,
  loadServerConfig,
  MISSING_SUPABASE_ENV_MESSAGE
} from "../src/config/env.js";

// Builds an unsigned, fake JWT-shaped string with the given payload.
// These are test fixtures only, not real keys.
function fakeJwt(payload: Record<string, unknown>): string {
  const encode = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString("base64url");

  return `${encode({ alg: "none", typ: "JWT" })}.${encode(payload)}.fake-signature`;
}

const URL_OK = "https://example-project.supabase.example.test";

describe("isPrivilegedSupabaseKey (decision D-001)", () => {
  it("accepts publishable keys", () => {
    expect(isPrivilegedSupabaseKey("sb_publishable_test_only")).toBe(false);
  });

  it("accepts legacy anon JWT keys", () => {
    expect(isPrivilegedSupabaseKey(fakeJwt({ role: "anon" }))).toBe(false);
  });

  it("rejects secret keys", () => {
    expect(isPrivilegedSupabaseKey("sb_secret_test_only")).toBe(true);
  });

  it("rejects legacy JWT keys with a privileged role", () => {
    expect(isPrivilegedSupabaseKey(fakeJwt({ role: "service_role" }))).toBe(true);
  });
});

describe("loadSupabaseEnv", () => {
  it("keeps the original message when variables are missing", () => {
    expect(() => loadSupabaseEnv({})).toThrow(MISSING_SUPABASE_ENV_MESSAGE);
  });

  it("accepts a valid URL and publishable key", () => {
    const env = loadSupabaseEnv({
      SUPABASE_URL: URL_OK,
      SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test_only"
    });

    expect(env.SUPABASE_URL).toBe(URL_OK);
  });

  it("rejects an invalid URL", () => {
    expect(() =>
      loadSupabaseEnv({
        SUPABASE_URL: "not-a-url",
        SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test_only"
      })
    ).toThrow(/SUPABASE_URL/);
  });

  it("refuses to start with a privileged key and never echoes the key", () => {
    const secret = "sb_secret_should_never_be_printed";
    let message = "";

    try {
      loadSupabaseEnv({ SUPABASE_URL: URL_OK, SUPABASE_PUBLISHABLE_KEY: secret });
    } catch (error) {
      message = (error as Error).message;
    }

    expect(message).toMatch(/publishable/);
    expect(message).not.toContain(secret);
  });
});

describe("env file locations (load-env)", () => {
  it("looks in backend/.env first, then the repository-root .env", async () => {
    const { join, relative } = await import("node:path");
    const { ENV_FILE_CANDIDATES } = await import("../src/config/load-env.js");
    const repoRoot = join(import.meta.dirname, "..", "..");

    expect(ENV_FILE_CANDIDATES.map((file) => relative(repoRoot, file))).toEqual([
      join("backend", ".env"),
      ".env"
    ]);
  });
});

describe("loadServerConfig", () => {
  it("uses safe defaults", () => {
    expect(loadServerConfig({})).toEqual({
      port: 3000,
      corsOrigins: [],
      rateLimitWindowMs: 900_000,
      rateLimitMax: 300,
      trustProxy: 0
    });
  });

  it("treats empty values as unset (like the original PORT || 3000)", () => {
    expect(
      loadServerConfig({
        PORT: "",
        CORS_ORIGINS: " ",
        RATE_LIMIT_WINDOW_MS: "",
        RATE_LIMIT_MAX: "",
        TRUST_PROXY: ""
      })
    ).toEqual(loadServerConfig({}));
  });

  it("rejects TRUST_PROXY=true (would let clients spoof their IP)", () => {
    expect(() => loadServerConfig({ TRUST_PROXY: "true" })).toThrow(/TRUST_PROXY/);
  });

  it("parses origins, limits and proxy settings", () => {
    const config = loadServerConfig({
      PORT: "4000",
      CORS_ORIGINS: " https://a.example.test , https://b.example.test,, ",
      RATE_LIMIT_WINDOW_MS: "1000",
      RATE_LIMIT_MAX: "5",
      TRUST_PROXY: "1"
    });

    expect(config).toEqual({
      port: 4000,
      corsOrigins: ["https://a.example.test", "https://b.example.test"],
      rateLimitWindowMs: 1000,
      rateLimitMax: 5,
      trustProxy: 1
    });
  });

  it("rejects invalid values", () => {
    expect(() => loadServerConfig({ PORT: "abc" })).toThrow(/PORT/);
    expect(() => loadServerConfig({ RATE_LIMIT_MAX: "0" })).toThrow(/RATE_LIMIT_MAX/);
  });
});
