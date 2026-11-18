import { describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseModuleFactory, mockValidUser, supabaseMocks, TEST_TOKEN } from "./helpers/mock-supabase-module.js";
import { testConfig } from "./helpers/config.js";
import {
  createSupabasePasswordResetClient,
  InvalidRecoveryTokenError,
  PasswordRejectedError,
  PasswordResetRateLimitedError,
  PasswordResetUnavailableError,
  passwordResetRedirectFromEnv,
  type PasswordResetClient
} from "../src/services/password-reset.service.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");

const REDIRECT = "http://127.0.0.1:8080/";

function fakeClient(overrides: Partial<PasswordResetClient> = {}) {
  const calls: { send: [string, string][]; update: [string, string][] } = { send: [], update: [] };
  const client: PasswordResetClient = {
    async sendResetEmail(email, redirectTo) { calls.send.push([email, redirectTo]); },
    async updatePassword(token, password) { calls.update.push([token, password]); },
    ...overrides
  };
  return { client, calls };
}

function appWith(client: PasswordResetClient | null) {
  return createApp(testConfig(), {
    machine: null, remediationDispatcher: null, prometheus: null, loki: null, github: null,
    passwordReset: client, passwordResetRedirectUrl: REDIRECT
  });
}

describe("POST /api/auth/forgot-password", () => {
  it("sends the reset email with the configured redirect and answers 202", async () => {
    const { client, calls } = fakeClient();
    const res = await request(appWith(client)).post("/api/auth/forgot-password").send({ email: "  Someone@Example.TEST " });

    expect(res.status).toBe(202);
    expect(res.body.message).toMatch(/If an account exists/);
    expect(calls.send).toEqual([["someone@example.test", REDIRECT]]);
  });

  it("needs no login", async () => {
    const res = await request(appWith(fakeClient().client)).post("/api/auth/forgot-password").send({ email: "a@b.test" });
    expect(res.status).toBe(202);
    expect(supabaseMocks.getUser).not.toHaveBeenCalled();
  });

  it.each([{}, { email: "" }, { email: "not-an-email" }, { email: 42 }])("rejects %j with 400", async (body) => {
    const { client, calls } = fakeClient();
    const res = await request(appWith(client)).post("/api/auth/forgot-password").send(body);
    expect(res.status).toBe(400);
    expect(calls.send).toHaveLength(0);
  });

  it("maps a Supabase rate limit to 429", async () => {
    const { client } = fakeClient({ sendResetEmail: async () => { throw new PasswordResetRateLimitedError("x"); } });
    const res = await request(appWith(client)).post("/api/auth/forgot-password").send({ email: "a@b.test" });
    expect(res.status).toBe(429);
  });

  it("answers 503 when Supabase is unreachable or not configured", async () => {
    const { client } = fakeClient({ sendResetEmail: async () => { throw new PasswordResetUnavailableError("down"); } });
    expect((await request(appWith(client)).post("/api/auth/forgot-password").send({ email: "a@b.test" })).status).toBe(503);
    expect((await request(appWith(null)).post("/api/auth/forgot-password").send({ email: "a@b.test" })).status).toBe(503);
  });

  it("limits reset requests per IP", async () => {
    const { client, calls } = fakeClient();
    const app = appWith(client);
    for (let i = 0; i < 5; i++) {
      expect((await request(app).post("/api/auth/forgot-password").send({ email: "a@b.test" })).status).toBe(202);
    }
    expect((await request(app).post("/api/auth/forgot-password").send({ email: "a@b.test" })).status).toBe(429);
    expect(calls.send).toHaveLength(5);
  });
});

describe("POST /api/auth/reset-password", () => {
  const auth = { Authorization: `Bearer ${TEST_TOKEN}` };

  it("requires the recovery token", async () => {
    const res = await request(appWith(fakeClient().client)).post("/api/auth/reset-password").send({ password: "long-enough-1" });
    expect(res.status).toBe(401);
  });

  it("sets the new password with the caller's recovery token", async () => {
    mockValidUser();
    const { client, calls } = fakeClient();
    const res = await request(appWith(client)).post("/api/auth/reset-password").set(auth).send({ password: "long-enough-1" });

    expect(res.status).toBe(200);
    expect(calls.update).toEqual([[TEST_TOKEN, "long-enough-1"]]);
  });

  it.each([{}, { password: "short" }, { password: "x".repeat(73) }, { password: 12345678 }])("rejects %j with 400", async (body) => {
    mockValidUser();
    const { client, calls } = fakeClient();
    const res = await request(appWith(client)).post("/api/auth/reset-password").set(auth).send(body);
    expect(res.status).toBe(400);
    expect(calls.update).toHaveLength(0);
  });

  it("maps Supabase errors", async () => {
    mockValidUser();
    const cases: [Error, number][] = [
      [new InvalidRecoveryTokenError("expired"), 401],
      [new PasswordRejectedError("weak"), 422],
      [new PasswordResetUnavailableError("down"), 503]
    ];
    for (const [error, status] of cases) {
      const { client } = fakeClient({ updatePassword: async () => { throw error; } });
      const res = await request(appWith(client)).post("/api/auth/reset-password").set(auth).send({ password: "long-enough-1" });
      expect(res.status).toBe(status);
    }
  });
});

describe("Supabase password reset client", () => {
  function fetchReturning(status: number, body: unknown = {}) {
    const calls: { url: string; init: RequestInit }[] = [];
    const impl = (async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return new Response(JSON.stringify(body), { status });
    }) as unknown as typeof fetch;
    return { impl, calls };
  }

  it("calls /recover with the publishable key and redirect", async () => {
    const { impl, calls } = fetchReturning(200);
    await createSupabasePasswordResetClient("https://p.supabase.test/", "sb_publishable_x", impl).sendResetEmail("a@b.test", REDIRECT);

    expect(calls[0].url).toBe("https://p.supabase.test/auth/v1/recover?redirect_to=http%3A%2F%2F127.0.0.1%3A8080%2F");
    expect((calls[0].init.headers as Record<string, string>).apikey).toBe("sb_publishable_x");
    expect(JSON.parse(String(calls[0].init.body))).toEqual({ email: "a@b.test" });
  });

  it("treats a 4xx for the email as sent (no account enumeration) but reports rate limits", async () => {
    await expect(createSupabasePasswordResetClient("https://p", "k", fetchReturning(400, { error_code: "user_not_found" }).impl)
      .sendResetEmail("a@b.test", REDIRECT)).resolves.toBeUndefined();
    await expect(createSupabasePasswordResetClient("https://p", "k", fetchReturning(429, { error_code: "over_email_send_rate_limit" }).impl)
      .sendResetEmail("a@b.test", REDIRECT)).rejects.toBeInstanceOf(PasswordResetRateLimitedError);
    await expect(createSupabasePasswordResetClient("https://p", "k", fetchReturning(500).impl)
      .sendResetEmail("a@b.test", REDIRECT)).rejects.toBeInstanceOf(PasswordResetUnavailableError);
  });

  it("updates the password with PUT /user and the recovery token", async () => {
    const { impl, calls } = fetchReturning(200, { id: "u" });
    await createSupabasePasswordResetClient("https://p", "k", impl).updatePassword("recovery-token", "new-password-1");

    expect(calls[0].url).toBe("https://p/auth/v1/user");
    expect(calls[0].init.method).toBe("PUT");
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe("Bearer recovery-token");
  });

  it("maps update errors", async () => {
    const client = (status: number, body = {}) => createSupabasePasswordResetClient("https://p", "k", fetchReturning(status, body).impl);
    await expect(client(401).updatePassword("t", "p")).rejects.toBeInstanceOf(InvalidRecoveryTokenError);
    await expect(client(422, { error_code: "weak_password", msg: "Password is too weak" }).updatePassword("t", "p"))
      .rejects.toThrow("Password is too weak");
    await expect(client(422, { error_code: "same_password" }).updatePassword("t", "p")).rejects.toThrow(/different/);
  });

  it("reports an unreachable Supabase", async () => {
    const impl = (async () => { throw new TypeError("fetch failed"); }) as unknown as typeof fetch;
    await expect(createSupabasePasswordResetClient("https://p", "k", impl).sendResetEmail("a@b.test", REDIRECT))
      .rejects.toBeInstanceOf(PasswordResetUnavailableError);
  });
});

describe("PASSWORD_RESET_REDIRECT_URL", () => {
  it("defaults to the local web app and validates the value", () => {
    expect(passwordResetRedirectFromEnv({})).toBe("http://127.0.0.1:8080/");
    expect(passwordResetRedirectFromEnv({ PASSWORD_RESET_REDIRECT_URL: "http://192.168.1.5:8080/" })).toBe("http://192.168.1.5:8080/");
    expect(() => passwordResetRedirectFromEnv({ PASSWORD_RESET_REDIRECT_URL: "javascript:alert(1)" })).toThrow();
    expect(() => passwordResetRedirectFromEnv({ PASSWORD_RESET_REDIRECT_URL: "not a url" })).toThrow();
  });
});
