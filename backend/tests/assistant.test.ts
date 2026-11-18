import { afterEach, describe, expect, it, vi } from "vitest";
import request from "supertest";

import { supabaseModuleFactory, supabaseMocks, mockValidUser, TEST_TOKEN } from "./helpers/mock-supabase-module.js";
import { testConfig } from "./helpers/config.js";
import {
  AssistantError,
  createGroqClient,
  parseExplanation,
  stripCommands,
  type AssistantClient
} from "../src/services/assistant.service.js";
import type { AssistantRateLimit } from "../src/routes/assistant.routes.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");
const auth = { Authorization: `Bearer ${TEST_TOKEN}` };
const PATH = "/api/assistant/explain";

const REPLY = JSON.stringify({
  meaning: "The app could not connect to PostgreSQL: the connection was refused.",
  likely_causes: ["The database is not running", "Wrong host or port"],
  next_checks: ["Check that the database container is up", "Check DATABASE_URL in the service settings"],
  confidence: 0.8
});

function fakeAssistant(reply: string | Error = REPLY) {
  const calls: { system: string; user: string }[] = [];
  const assistant: AssistantClient = {
    model: "test-model",
    async complete(system, user) {
      calls.push({ system, user });
      if (reply instanceof Error) throw reply;
      return reply;
    }
  };
  return { assistant, calls };
}

const app = (assistant: AssistantClient | null, assistantRateLimit: AssistantRateLimit = { windowMs: 60000, max: 100 }) =>
  createApp(testConfig(), { machine: null, remediationDispatcher: null, prometheus: null, loki: null, assistant, assistantRateLimit });

afterEach(() => vi.restoreAllMocks());

describe("POST /api/assistant/explain", () => {
  it("requires sign-in", async () => {
    const res = await request(app(fakeAssistant().assistant)).post(PATH).send({ text: "error" });
    expect(res.status).toBe(401);
  });

  it("answers 503 with a clear message when GROQ_API_KEY is missing", async () => {
    mockValidUser();
    const res = await request(app(null)).post(PATH).set(auth).send({ text: "error" });
    expect(res.status).toBe(503);
    expect(res.body.message).toBe("The developer assistant is not configured: GROQ_API_KEY is missing in backend/.env.");
  });

  it("explains the text and returns meaning, causes, checks, confidence and the model", async () => {
    mockValidUser();
    const { assistant, calls } = fakeAssistant();
    const res = await request(app(assistant)).post(PATH).set(auth)
      .send({ text: "psycopg2.OperationalError: connection refused (127.0.0.1:5432)" });

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({
      meaning: "The app could not connect to PostgreSQL: the connection was refused.",
      likely_causes: ["The database is not running", "Wrong host or port"],
      next_checks: ["Check that the database container is up", "Check DATABASE_URL in the service settings"],
      confidence: 0.8,
      redacted_count: 0,
      model: "test-model"
    });
    expect(calls[0]?.user).toContain("connection refused (127.0.0.1:5432)");
    expect(calls[0]?.system).toMatch(/Never write shell commands/);
  });

  it("removes secrets BEFORE the text is sent to the AI and reports how many", async () => {
    mockValidUser();
    const { assistant, calls } = fakeAssistant();
    const secrets = {
      password: "hunter2-very-secret",
      groq: "gsk_" + "A".repeat(40),
      jwt: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.c2lnbmF0dXJlLXZhbHVl",
      dbPassword: "pa55w0rd-db"
    };
    const text = [
      `ERROR login failed password=${secrets.password}`,
      `using key ${secrets.groq}`,
      `Authorization: Bearer ${secrets.jwt}`,
      `DATABASE_URL=postgres://app:${secrets.dbPassword}@db:5432/app`
    ].join("\n");

    const res = await request(app(assistant)).post(PATH).set(auth).send({ text });

    expect(res.status).toBe(200);
    const sent = calls[0]!.user;
    for (const value of Object.values(secrets)) expect(sent).not.toContain(value);
    expect(sent).toContain("password=[redacted]");
    expect(sent).toContain("postgres://app:[redacted]@db:5432/app");
    expect(sent).toContain("ERROR login failed");
    expect(res.body.data.redacted_count).toBe(4);
  });

  it("never logs the pasted text or the AI reply", async () => {
    mockValidUser();
    const logs = [vi.spyOn(console, "log"), vi.spyOn(console, "error"), vi.spyOn(console, "warn"), vi.spyOn(console, "info")];
    for (const spy of logs) spy.mockImplementation(() => undefined);
    const pasted = "UNIQUE-PASTED-MARKER connection refused";

    await request(app(fakeAssistant().assistant)).post(PATH).set(auth).send({ text: pasted });
    await request(app(fakeAssistant(new AssistantError("timeout", "The AI service did not answer in time.")).assistant))
      .post(PATH).set(auth).send({ text: pasted });

    const printed = logs.flatMap((spy) => spy.mock.calls.flat().map(String)).join("\n");
    expect(printed).not.toContain("UNIQUE-PASTED-MARKER");
    expect(printed).not.toContain("could not connect to PostgreSQL");
  });

  it.each([
    [{}, "Paste a log snippet"],
    [{ text: "   " }, "Paste a log snippet"],
    [{ text: 42 }, "Paste a log snippet"],
    [{ text: "x".repeat(8001) }, "too long"]
  ])("rejects %j with 400", async (body, message) => {
    mockValidUser();
    const { assistant, calls } = fakeAssistant();
    const res = await request(app(assistant)).post(PATH).set(auth).send(body);
    expect(res.status).toBe(400);
    expect(res.body.message).toContain(message);
    expect(calls).toHaveLength(0);
  });

  it.each([
    ["timeout", 504],
    ["rate_limited", 503],
    ["auth", 502],
    ["unavailable", 502],
    ["invalid_response", 502]
  ] as const)("maps an AI %s error to HTTP %i", async (kind, status) => {
    mockValidUser();
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    const res = await request(app(fakeAssistant(new AssistantError(kind, "message for " + kind)).assistant))
      .post(PATH).set(auth).send({ text: "error" });
    expect(res.status).toBe(status);
    expect(res.body.message).toBe("message for " + kind);
  });

  it("limits each user separately (429 after the limit)", async () => {
    const limited = app(fakeAssistant().assistant, { windowMs: 60000, max: 2 });
    const asUser = (id: string) => supabaseMocks.getUser.mockResolvedValue({ data: { user: { id, email: `${id}@example.test` } }, error: null });

    asUser("user-a");
    expect((await request(limited).post(PATH).set(auth).send({ text: "e1" })).status).toBe(200);
    expect((await request(limited).post(PATH).set(auth).send({ text: "e2" })).status).toBe(200);
    const third = await request(limited).post(PATH).set(auth).send({ text: "e3" });
    expect(third.status).toBe(429);
    expect(third.body.message).toMatch(/Too many explanations/);

    asUser("user-b");
    expect((await request(limited).post(PATH).set(auth).send({ text: "e1" })).status).toBe(200);
  });
});

describe("parseExplanation and stripCommands", () => {
  it("removes code blocks and command lines from the reply", () => {
    const out = parseExplanation(JSON.stringify({
      meaning: "Disk is full.\n```bash\nrm -rf /var/log/*\n```\n$ sudo systemctl restart app\nThe log volume has no space left.",
      likely_causes: ["Logs are not rotated"],
      next_checks: ["$ df -h", "Check the disk usage graph"],
      confidence: 2
    }));
    expect(out.meaning).not.toMatch(/rm -rf|systemctl/);
    expect(out.meaning).toContain("The log volume has no space left.");
    expect(out.next_checks).toEqual(["Check the disk usage graph"]);
    expect(out.confidence).toBe(1);
  });

  it("redacts secrets the model repeats, limits lists to 5 and accepts a fenced JSON reply", () => {
    const out = parseExplanation("```json\n" + JSON.stringify({
      meaning: "The token gsk_" + "B".repeat(30) + " was rejected.",
      likely_causes: ["a", "b", "c", "d", "e", "f", 7],
      next_checks: [],
      confidence: 0.4
    }) + "\n```");
    expect(out.meaning).toBe("The token [redacted] was rejected.");
    expect(out.likely_causes).toEqual(["a", "b", "c", "d", "e"]);
  });

  it("rejects replies that are not the expected JSON", () => {
    expect(() => parseExplanation("not json")).toThrow(AssistantError);
    expect(() => parseExplanation("[]")).toThrow(/unexpected shape/);
    expect(() => parseExplanation(JSON.stringify({ meaning: "" }))).toThrow(/no explanation/);
  });

  it("stripCommands keeps normal text", () => {
    expect(stripCommands("Check the `DATABASE_URL` setting.")).toBe("Check the DATABASE_URL setting.");
  });
});

describe("createGroqClient", () => {
  const options = { apiKey: "test-only-groq-key", model: "m", baseUrl: "https://groq.example.test/openai/v1/", timeoutMs: 1000 };

  it("posts a JSON-mode chat completion with the key in the header and returns the content", async () => {
    const fetchImpl = vi.fn(async () => new Response(JSON.stringify({ choices: [{ message: { content: REPLY } }] }), { status: 200 }));
    const client = createGroqClient({ ...options, fetchImpl: fetchImpl as unknown as typeof fetch });

    expect(await client.complete("sys", "usr")).toBe(REPLY);
    const [url, init] = fetchImpl.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://groq.example.test/openai/v1/chat/completions");
    expect((init.headers as Record<string, string>).Authorization).toBe("Bearer test-only-groq-key");
    const body = JSON.parse(String(init.body));
    expect(body.response_format).toEqual({ type: "json_object" });
    expect(body.messages).toEqual([{ role: "system", content: "sys" }, { role: "user", content: "usr" }]);
  });

  it.each([
    [429, "rate_limited"],
    [401, "auth"],
    [500, "unavailable"]
  ] as const)("HTTP %i -> %s, and the error never contains the response body", async (status, kind) => {
    const fetchImpl = vi.fn(async () => new Response("echo of the request: secret-body", { status }));
    const client = createGroqClient({ ...options, fetchImpl: fetchImpl as unknown as typeof fetch });

    const error = await client.complete("s", "u").catch((e: unknown) => e as AssistantError);
    expect(error).toBeInstanceOf(AssistantError);
    expect((error as AssistantError).kind).toBe(kind);
    expect((error as AssistantError).message).not.toContain("secret-body");
  });

  it("a timeout is reported as timeout", async () => {
    const fetchImpl = vi.fn(async () => { throw Object.assign(new Error("aborted"), { name: "TimeoutError" }); });
    const client = createGroqClient({ ...options, fetchImpl: fetchImpl as unknown as typeof fetch });
    await expect(client.complete("s", "u")).rejects.toMatchObject({ kind: "timeout" });
  });
});
