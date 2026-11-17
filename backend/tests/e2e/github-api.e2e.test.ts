import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";

import {
  supabaseMocks,
  supabaseModuleFactory,
  mockValidUser,
  TEST_TOKEN
} from "../helpers/mock-supabase-module.js";
import { createMockUserClient } from "../helpers/supabase-mock.js";
import { testConfig } from "../helpers/config.js";
import { commitFixture, jobFixture, pullFixture, repoFixture, runFixture } from "../helpers/github-fixtures.js";
import { loopbackOnly, reply, startHttpMock } from "./helpers/mock-servers.js";

vi.mock("../../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../../src/app.js");
const { GitHubService } = await import("../../src/integrations/github/github.service.js");

// M7 – End-to-end GitHub integration (test IDs E2E-G01..G06, see
// docs/m7/TEST_RESULTS.md).
//
// Path under test: mobile-style HTTP request -> Express app (auth,
// validation, routes) -> GitHubService -> real HTTP -> local mock GitHub
// REST API -> mapped JSON response. Supabase Auth is mocked; no real GitHub
// resource is read or changed.

const realFetch = globalThis.fetch; // captured before tests/setup.ts blocks it
const GH_TOKEN = "github_pat_E2ETOKEN0123456789abcdefghijk";

type Scenario = "normal" | "rate_limited" | "revoked" | "slow";
let scenario: Scenario = "normal";
let github: Awaited<ReturnType<typeof startHttpMock>>;

beforeAll(async () => {
  github = await startHttpMock((req, res) => {
    if (scenario === "slow") return; // never answers
    if (scenario === "revoked") return reply(res, 401, { message: "Bad credentials" });
    if (scenario === "rate_limited") {
      const reset = Math.floor(Date.now() / 1000) + 90;
      return reply(res, 403, { message: "API rate limit exceeded" }, {
        "x-ratelimit-remaining": "0",
        "x-ratelimit-reset": String(reset)
      });
    }
    if (req.headers.authorization !== `Bearer ${GH_TOKEN}`) return reply(res, 401, { message: "Bad credentials" });

    const path = req.path.split("?")[0];
    const routes: Record<string, unknown> = {
      "/repos/acme/payments-api": repoFixture(),
      "/repos/acme/payments-api/commits": [commitFixture("a91f3c2deadbeef", "Tune DB pool settings")],
      "/repos/acme/payments-api/pulls": [pullFixture(214, { state: "closed", merged_at: "2026-11-01T10:00:00Z" })],
      "/repos/acme/payments-api/pulls/214": pullFixture(214, { additions: 12, deletions: 4, changed_files: 2, commits: 1 }),
      "/repos/acme/payments-api/actions/runs": { total_count: 1, workflow_runs: [runFixture(318, "failure")] },
      "/repos/acme/payments-api/actions/runs/318/jobs": { total_count: 1, jobs: [jobFixture(901)] }
    };
    if (path in routes) return reply(res, 200, routes[path], { "x-ratelimit-remaining": "4999" });
    reply(res, 404, { message: "Not Found" });
  });
});

afterAll(() => github.close());

function app(cacheTtlMs = 0) {
  const service = new GitHubService(
    {
      token: GH_TOKEN,
      repositories: [{ owner: "acme", repo: "payments-api" }],
      apiUrl: github.url,
      timeoutMs: 1000,
      cacheTtlMs
    },
    { fetchImpl: loopbackOnly(realFetch) }
  );
  return createApp(testConfig(), { machine: null, github: service });
}

const auth = { Authorization: `Bearer ${TEST_TOKEN}` };
const base = "/api/github/repositories/acme/payments-api";

beforeEach(() => {
  scenario = "normal";
  mockValidUser();
  supabaseMocks.createUserSupabaseClient.mockReturnValue(createMockUserClient().client);
  vi.spyOn(console, "error").mockImplementation(() => {});
  vi.spyOn(console, "warn").mockImplementation(() => {});
});

describe("E2E GitHub integration (mobile -> backend -> GitHub)", () => {
  it("E2E-G01 serves the Repositories screen flow: repos, commits, PRs, PR detail, runs, jobs", async () => {
    const api = app();
    const before = github.requests.length;

    const repos = await request(api).get("/api/github/repositories").set(auth);
    expect(repos.status).toBe(200);
    expect(repos.body.data[0]).toMatchObject({ full_name: "acme/payments-api", default_branch: "main" });

    const commits = await request(api).get(`${base}/commits?limit=5`).set(auth);
    expect(commits.body.data[0]).toMatchObject({ short_sha: "a91f3c2", title: "Tune DB pool settings", author_login: "devone" });
    expect(JSON.stringify(commits.body)).not.toContain("@example.test");

    const pulls = await request(api).get(`${base}/pulls?state=closed`).set(auth);
    expect(pulls.body.data[0]).toMatchObject({ number: 214, merged: true });

    const pr = await request(api).get(`${base}/pulls/214`).set(auth);
    expect(pr.body.data).toMatchObject({ number: 214, additions: 12, deletions: 4 });

    const runs = await request(api).get(`${base}/workflow-runs?status=failure`).set(auth);
    expect(runs.body.data[0]).toMatchObject({ id: 318, conclusion: "failure", branch: "main" });

    const jobs = await request(api).get(`${base}/workflow-runs/318/jobs`).set(auth);
    expect(jobs.body.data[0].steps.map((s: { conclusion: string }) => s.conclusion)).toEqual(["success", "failure"]);

    // What GitHub received: read-only GETs with the backend token and API version
    const sent = github.requests.slice(before);
    expect(sent.map((r) => `${r.method} ${r.path}`)).toEqual([
      "GET /repos/acme/payments-api",
      "GET /repos/acme/payments-api/commits?per_page=5",
      "GET /repos/acme/payments-api/pulls?state=closed&sort=updated&direction=desc&per_page=20",
      "GET /repos/acme/payments-api/pulls/214",
      "GET /repos/acme/payments-api/actions/runs?status=failure&per_page=20",
      "GET /repos/acme/payments-api/actions/runs/318/jobs?per_page=100"
    ]);
    for (const r of sent) {
      expect(r.headers["x-github-api-version"]).toBe("2022-11-28");
      expect(r.headers.accept).toBe("application/vnd.github+json");
    }
  });

  it("E2E-G02 stops calling GitHub after a rate limit and tells the client when to retry", async () => {
    const api = app();
    scenario = "rate_limited";
    const before = github.requests.length;

    const first = await request(api).get(base).set(auth);
    expect(first.status).toBe(503);
    expect(Number(first.headers["retry-after"])).toBeGreaterThan(80);

    scenario = "normal";
    const second = await request(api).get(base).set(auth);
    expect(second.status).toBe(503); // still within the reset window
    expect(github.requests.length - before).toBe(1); // second call never reached GitHub
  });

  it("E2E-G03 reports a revoked backend token as 502 without exposing it", async () => {
    scenario = "revoked";
    const res = await request(app()).get(`${base}/commits`).set(auth);

    expect(res.status).toBe(502);
    expect(res.body).toEqual({ success: false, message: "GitHub integration is misconfigured." });
    expect(JSON.stringify(res.body)).not.toContain(GH_TOKEN);
  });

  it("E2E-G04 times out (with one retry) when GitHub does not answer", async () => {
    scenario = "slow";
    const before = github.requests.length;
    const started = Date.now();
    const res = await request(app()).get(base).set(auth);

    expect(res.status).toBe(502);
    expect(github.requests.length - before).toBe(2);
    expect(Date.now() - started).toBeLessThan(5000);
  }, 10_000);

  it("E2E-G05 shares one GitHub request between clients within the cache TTL", async () => {
    const api = app(30_000);
    const before = github.requests.length;

    for (let i = 0; i < 3; i += 1) {
      expect((await request(api).get(`${base}/commits`).set(auth)).status).toBe(200);
    }
    expect(github.requests.length - before).toBe(1);
  });

  it("E2E-G06 refuses unlisted repositories and unauthenticated callers without contacting GitHub", async () => {
    const api = app();
    const before = github.requests.length;

    expect((await request(api).get("/api/github/repositories/acme/secret-repo").set(auth)).status).toBe(404);
    expect((await request(api).get(`${base}/commits`)).status).toBe(401);
    expect(github.requests.length).toBe(before);
  });
});
