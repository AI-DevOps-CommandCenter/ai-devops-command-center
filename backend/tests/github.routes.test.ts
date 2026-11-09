import { beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";

import {
  supabaseMocks,
  supabaseModuleFactory,
  mockValidUser,
  TEST_TOKEN
} from "./helpers/mock-supabase-module.js";
import { createMockUserClient } from "./helpers/supabase-mock.js";
import { testConfig } from "./helpers/config.js";
import { createFakeFetch, type FakeReply } from "./helpers/fake-fetch.js";
import { commitFixture, pullFixture, repoFixture, runFixture, jobFixture } from "./helpers/github-fixtures.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

const { createApp } = await import("../src/app.js");
const { GitHubService } = await import("../src/integrations/github/github.service.js");

// M7 – GitHub REST endpoints (/api/github/*). Supabase auth is mocked;
// GitHub is a scripted fake fetch.

const TOKEN = "github_pat_ROUTESTOKEN0123456789abcdefgh";

function appWith(replies: FakeReply[] | ((url: string) => FakeReply)) {
  const fake = createFakeFetch(replies);
  const service = new GitHubService(
    {
      token: TOKEN,
      repositories: [
        { owner: "acme", repo: "payments-api" },
        { owner: "acme", repo: "web" }
      ],
      apiUrl: "https://api.github.test",
      timeoutMs: 1000,
      cacheTtlMs: 0
    },
    { fetchImpl: fake.fetchImpl, sleep: () => Promise.resolve() }
  );
  return { app: createApp(testConfig(), { machine: null, github: service }), ...fake };
}

const auth = { Authorization: `Bearer ${TEST_TOKEN}` };

beforeEach(() => {
  mockValidUser();
  supabaseMocks.createUserSupabaseClient.mockReturnValue(createMockUserClient().client);
});

describe("GitHub endpoints – access", () => {
  it("require a signed-in user", async () => {
    const { app, requests } = appWith([]);
    const res = await request(app).get("/api/github/repositories");

    expect(res.status).toBe(401);
    expect(res.body).toEqual({ success: false, message: "Authentication token is required." });
    expect(requests).toHaveLength(0);
  });

  it("answer 503 when the integration is not configured", async () => {
    const app = createApp(testConfig(), { machine: null, github: null });
    const res = await request(app).get("/api/github/repositories").set(auth);

    expect(res.status).toBe(503);
    expect(res.body).toEqual({ success: false, message: "GitHub integration is not configured." });
  });

  it("are disabled by default when no GitHub variables are set", async () => {
    const app = createApp(testConfig(), { machine: null });
    const res = await request(app).get("/api/github/repositories").set(auth);
    expect(res.status).toBe(503);
  });

  it("never serve a repository outside the allow-list (no GitHub call)", async () => {
    const { app, requests } = appWith([]);
    const res = await request(app).get("/api/github/repositories/torvalds/linux/commits").set(auth);

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ success: false, message: "Repository not found." });
    expect(requests).toHaveLength(0);
  });

  it.each([
    ["/api/github/repositories/acme/payments-api/commits?limit=0", "query"],
    ["/api/github/repositories/acme/payments-api/commits?limit=101", "query"],
    ["/api/github/repositories/acme/payments-api/commits?branch=..%2Fsecret", "query"],
    ["/api/github/repositories/acme/payments-api/pulls?state=merged", "query"],
    ["/api/github/repositories/acme/payments-api/pulls/abc", "params"],
    ["/api/github/repositories/acme/payments-api/workflow-runs?status=bogus", "query"],
    ["/api/github/repositories/acme/payments-api/workflow-runs/-1/jobs", "params"],
    ["/api/github/repositories/ac%20me/payments-api", "params"]
  ])("reject invalid input %s", async (path, location) => {
    const { app, requests } = appWith([]);
    const res = await request(app).get(path).set(auth);

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.errors[0].location).toBe(location);
    expect(requests).toHaveLength(0);
  });
});

describe("GitHub endpoints – data", () => {
  it("list the configured repositories", async () => {
    const { app } = appWith((url) =>
      url.endsWith("/repos/acme/web") ? { json: repoFixture("acme", "web") } : { json: repoFixture() }
    );
    const res = await request(app).get("/api/github/repositories").set(auth);

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ success: true, count: 2 });
    expect(res.body.data.map((r: { full_name: string }) => r.full_name)).toEqual(["acme/payments-api", "acme/web"]);
    expect(res.body.data[0]).not.toHaveProperty("permissions");
  });

  it("return recent commits with the default limit of 20", async () => {
    const { app, requests } = appWith([{ json: [commitFixture("a91f3c2deadbeef", "Tune DB pool settings")] }]);
    const res = await request(app).get("/api/github/repositories/ACME/payments-api/commits?branch=main").set(auth);

    expect(res.status).toBe(200);
    expect(res.body.data[0]).toMatchObject({ short_sha: "a91f3c2", title: "Tune DB pool settings" });
    expect(requests[0].url).toContain("/repos/acme/payments-api/commits?sha=main&per_page=20");
    expect(JSON.stringify(res.body)).not.toContain("dev.one@example.test");
  });

  it("return pull requests, a pull request, workflow runs and jobs", async () => {
    const { app } = appWith([
      { json: [pullFixture(214, { state: "closed", merged_at: "2026-11-01T00:00:00Z" })] },
      { json: pullFixture(214, { additions: 10, deletions: 2, changed_files: 3, commits: 1 }) },
      { json: { total_count: 1, workflow_runs: [runFixture(318, "failure")] } },
      { json: { total_count: 1, jobs: [jobFixture(5)] } }
    ]);

    const pulls = await request(app).get("/api/github/repositories/acme/payments-api/pulls?state=all").set(auth);
    expect(pulls.body.data[0]).toMatchObject({ number: 214, merged: true });

    const pr = await request(app).get("/api/github/repositories/acme/payments-api/pulls/214").set(auth);
    expect(pr.body.data).toMatchObject({ number: 214, additions: 10, changed_files: 3 });

    const runs = await request(app).get("/api/github/repositories/acme/payments-api/workflow-runs?status=failure").set(auth);
    expect(runs.body).toMatchObject({ count: 1, data: [{ id: 318, conclusion: "failure" }] });

    const jobs = await request(app).get("/api/github/repositories/acme/payments-api/workflow-runs/318/jobs").set(auth);
    expect(jobs.body.data[0].steps).toHaveLength(2);
  });
});

describe("GitHub endpoints – GitHub failures", () => {
  beforeEach(() => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
  });

  it("map a GitHub 404 to 404", async () => {
    const { app } = appWith([{ status: 404, json: { message: "Not Found" } }]);
    const res = await request(app).get("/api/github/repositories/acme/payments-api/pulls/9999").set(auth);
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ success: false, message: "GitHub resource not found." });
  });

  it("map a rejected backend token to 502, not 401, and hide the token", async () => {
    const { app } = appWith([{ status: 401, json: { message: "Bad credentials" } }]);
    const res = await request(app).get("/api/github/repositories/acme/payments-api").set(auth);

    expect(res.status).toBe(502);
    expect(res.body).toEqual({ success: false, message: "GitHub integration is misconfigured." });
    expect(JSON.stringify(res.body)).not.toContain(TOKEN);
  });

  it("map a rate limit to 503 with Retry-After", async () => {
    const { app } = appWith([{ status: 429, headers: { "retry-after": "42" } }]);
    const res = await request(app).get("/api/github/repositories/acme/payments-api").set(auth);

    expect(res.status).toBe(503);
    expect(res.headers["retry-after"]).toBe("42");
  });

  it("map outages and unexpected payloads to 502", async () => {
    const outage = appWith([{ status: 500 }, { status: 500 }]);
    expect((await request(outage.app).get("/api/github/repositories/acme/web").set(auth)).status).toBe(502);

    const weird = appWith([{ json: { not: "an array" } }]);
    const res = await request(weird.app).get("/api/github/repositories/acme/web/commits").set(auth);
    expect(res.status).toBe(502);
    expect(res.body).toEqual({ success: false, message: "GitHub is currently unavailable." });
  });
});
