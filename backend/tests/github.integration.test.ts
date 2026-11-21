import { describe, expect, it, vi } from "vitest";

import { loadGitHubConfig, parseRepositoryList, type GitHubConfig } from "../src/integrations/github/github.config.js";
import { GitHubClient, GitHubError, GITHUB_API_VERSION } from "../src/integrations/github/github.client.js";
import {
  GitHubService,
  mapCommit,
  mapPullRequest,
  mapWorkflowRun
} from "../src/integrations/github/github.service.js";
import { createFakeFetch } from "./helpers/fake-fetch.js";
import { commitFixture, pullFixture, repoFixture, runFixture, jobFixture } from "./helpers/github-fixtures.js";

// M7 – GitHub integration, unit level (fake fetch, no network).

const TOKEN = "github_pat_TESTTOKEN0123456789abcdefghij";

function config(overrides: Partial<GitHubConfig> = {}): GitHubConfig {
  return {
    token: TOKEN,
    repositories: [{ owner: "acme", repo: "payments-api" }],
    apiUrl: "https://api.github.test",
    timeoutMs: 1000,
    cacheTtlMs: 0,
    ...overrides
  };
}

const noSleep = () => Promise.resolve();

describe("GitHub configuration", () => {
  it("is disabled when nothing is set", () => {
    expect(loadGitHubConfig({})).toBeNull();
  });

  it("names the missing variable without printing values", () => {
    expect(() => loadGitHubConfig({ GITHUB_TOKEN: TOKEN })).toThrow(
      "Invalid GitHub configuration: missing GITHUB_REPOSITORIES"
    );
    try {
      loadGitHubConfig({ GITHUB_REPOSITORIES: "acme/x" });
    } catch (error) {
      expect(String(error)).toContain("missing GITHUB_TOKEN");
    }
  });

  it("parses the allow-list and applies defaults", () => {
    const cfg = loadGitHubConfig({ GITHUB_TOKEN: TOKEN, GITHUB_REPOSITORIES: " acme/api , acme/web,ACME/API " });
    expect(cfg).toEqual({
      token: TOKEN,
      repositories: [
        { owner: "acme", repo: "api" },
        { owner: "acme", repo: "web" }
      ],
      apiUrl: "https://api.github.com",
      timeoutMs: 10_000,
      cacheTtlMs: 30_000
    });
  });

  it.each(["acme", "acme/api/extra", "acme/..", "ac me/api", "/api"])("rejects repository entry %j", (entry) => {
    expect(() => parseRepositoryList(entry)).toThrow(/owner\/repo/);
  });

  it("requires an https API URL", () => {
    expect(() =>
      loadGitHubConfig({ GITHUB_TOKEN: TOKEN, GITHUB_REPOSITORIES: "a/b", GITHUB_API_URL: "http://github.local" })
    ).toThrow(/GITHUB_API_URL/);
  });
});

describe("GitHubClient", () => {
  it("sends the token and GitHub's recommended headers", async () => {
    const { fetchImpl, requests } = createFakeFetch([{ json: repoFixture() }]);
    await new GitHubClient(config(), { fetchImpl }).get("/repos/acme/payments-api", { per_page: 5, sha: undefined });

    expect(requests[0].url).toBe("https://api.github.test/repos/acme/payments-api?per_page=5");
    expect(requests[0].headers).toMatchObject({
      authorization: `Bearer ${TOKEN}`,
      accept: "application/vnd.github+json",
      "x-github-api-version": GITHUB_API_VERSION
    });
    expect(requests[0].headers["user-agent"]).toBeTruthy();
  });

  it("retries once on a 5xx, then succeeds", async () => {
    const { fetchImpl, requests } = createFakeFetch([{ status: 502, text: "bad gateway" }, { json: { ok: 1 } }]);
    const body = await new GitHubClient(config(), { fetchImpl, sleep: noSleep }).get("/x");
    expect(body).toEqual({ ok: 1 });
    expect(requests).toHaveLength(2);
  });

  it("reports unavailable after the retry also fails", async () => {
    const { fetchImpl, requests } = createFakeFetch([{ networkError: true }, { status: 503 }]);
    await expect(new GitHubClient(config(), { fetchImpl, sleep: noSleep }).get("/x")).rejects.toMatchObject({
      kind: "unavailable"
    });
    expect(requests).toHaveLength(2);
  });

  it("times out a hanging request", async () => {
    const { fetchImpl } = createFakeFetch([{ hang: true }, { hang: true }]);
    await expect(
      new GitHubClient(config({ timeoutMs: 1000 }), { fetchImpl, sleep: noSleep }).get("/x")
    ).rejects.toMatchObject({ kind: "unavailable" });
  }, 5000);

  it("does not retry 401 and reports auth without leaking the token", async () => {
    const error = vi.spyOn(console, "error").mockImplementation(() => {});
    const { fetchImpl, requests } = createFakeFetch([{ status: 401, json: { message: "Bad credentials" } }]);
    const err = await new GitHubClient(config(), { fetchImpl, sleep: noSleep }).get("/x").catch((e: unknown) => e);

    expect(err).toBeInstanceOf(GitHubError);
    expect((err as GitHubError).kind).toBe("auth");
    expect(requests).toHaveLength(1);
    expect(JSON.stringify(error.mock.calls)).not.toContain(TOKEN);
  });

  it("maps 404 to not_found", async () => {
    const { fetchImpl } = createFakeFetch([{ status: 404, json: { message: "Not Found" } }]);
    await expect(new GitHubClient(config(), { fetchImpl }).get("/x")).rejects.toMatchObject({ kind: "not_found" });
  });

  it("stops calling GitHub after a primary rate limit until the reset time", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    let now = 1_700_000_000_000;
    const reset = Math.floor(now / 1000) + 120;
    const { fetchImpl, requests } = createFakeFetch([
      { status: 403, json: { message: "API rate limit exceeded" }, headers: { "x-ratelimit-remaining": "0", "x-ratelimit-reset": String(reset) } },
      { json: { ok: true } }
    ]);
    const client = new GitHubClient(config(), { fetchImpl, now: () => now });

    const first = (await client.get("/x").catch((e: unknown) => e)) as GitHubError;
    expect(first.kind).toBe("rate_limited");
    expect(first.retryAfterMs).toBe(120_000);

    now += 60_000;
    const second = (await client.get("/x").catch((e: unknown) => e)) as GitHubError;
    expect(second.kind).toBe("rate_limited");
    expect(second.retryAfterMs).toBe(60_000);
    expect(requests).toHaveLength(1); // no request while blocked

    now += 61_000;
    await expect(client.get("/x")).resolves.toEqual({ ok: true });
    expect(requests).toHaveLength(2);
  });

  it("treats a secondary rate limit (429 + Retry-After) the same way", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const { fetchImpl } = createFakeFetch([{ status: 429, headers: { "retry-after": "30" } }]);
    await expect(new GitHubClient(config(), { fetchImpl }).get("/x")).rejects.toMatchObject({
      kind: "rate_limited",
      retryAfterMs: 30_000
    });
  });

  it("caches successful responses for the TTL", async () => {
    let now = 0;
    const { fetchImpl, requests } = createFakeFetch([{ json: { n: 1 } }, { json: { n: 2 } }]);
    const client = new GitHubClient(config({ cacheTtlMs: 30_000 }), { fetchImpl, now: () => now });

    expect(await client.get("/x")).toEqual({ n: 1 });
    now = 29_000;
    expect(await client.get("/x")).toEqual({ n: 1 });
    now = 31_000;
    expect(await client.get("/x")).toEqual({ n: 2 });
    expect(requests).toHaveLength(2);
  });

  it("does not follow redirects (renamed repositories report an error)", async () => {
    const { fetchImpl } = createFakeFetch([{ status: 301, json: { message: "Moved Permanently" } }]);
    await expect(new GitHubClient(config(), { fetchImpl }).get("/x")).rejects.toMatchObject({ kind: "unavailable" });
  });
});

describe("GitHub response mapping", () => {
  it("maps a commit without the author's e-mail", () => {
    const mapped = mapCommit(commitFixture("a91f3c2deadbeef", "Tune DB pool settings\n\nLonger body"));
    expect(mapped).toMatchObject({
      sha: "a91f3c2deadbeef",
      short_sha: "a91f3c2",
      title: "Tune DB pool settings",
      author_name: "Dev One",
      author_login: "devone"
    });
    expect(JSON.stringify(mapped)).not.toContain("@");
  });

  it("maps merged pull requests", () => {
    expect(mapPullRequest(pullFixture(214, { merged_at: "2026-11-01T10:00:00Z", state: "closed" }))).toMatchObject({
      number: 214,
      state: "closed",
      merged: true,
      head_branch: "feature/pool",
      base_branch: "main"
    });
  });

  it("maps workflow runs", () => {
    expect(mapWorkflowRun(runFixture(318, "failure"))).toMatchObject({
      id: 318,
      conclusion: "failure",
      branch: "main",
      actor_login: "devone"
    });
  });

  it("rejects payloads of the wrong shape", () => {
    expect(() => mapCommit({ nope: true })).toThrow(GitHubError);
    expect(() => mapPullRequest("text")).toThrow(/Unexpected GitHub response/);
  });
});

describe("GitHubService", () => {
  it("resolves only allow-listed repositories (case-insensitive)", () => {
    const service = new GitHubService(config());
    expect(service.resolveRepository("ACME", "Payments-API")).toEqual({ owner: "acme", repo: "payments-api" });
    expect(service.resolveRepository("other", "repo")).toBeNull();
  });

  it("calls the documented GitHub endpoints", async () => {
    const { fetchImpl, requests } = createFakeFetch([
      { json: [commitFixture("abc1234567", "c")] },
      { json: [pullFixture(1)] },
      { json: pullFixture(1, { body: "x".repeat(6000), additions: 3 }) },
      { json: { total_count: 1, workflow_runs: [runFixture(9, "success")] } },
      { json: { total_count: 1, jobs: [jobFixture(77)] } }
    ]);
    const service = new GitHubService(config(), { fetchImpl });
    const ref = { owner: "acme", repo: "payments-api" };

    await service.listCommits(ref, { branch: "main", limit: 5 });
    await service.listPullRequests(ref, { state: "all", limit: 10 });
    const pr = await service.getPullRequest(ref, 1);
    await service.listWorkflowRuns(ref, { status: "failure", limit: 3 });
    const jobs = await service.listWorkflowRunJobs(ref, 9);

    expect(requests.map((r) => r.url.replace("https://api.github.test", ""))).toEqual([
      "/repos/acme/payments-api/commits?sha=main&per_page=5",
      "/repos/acme/payments-api/pulls?state=all&sort=updated&direction=desc&per_page=10",
      "/repos/acme/payments-api/pulls/1",
      "/repos/acme/payments-api/actions/runs?status=failure&per_page=3",
      "/repos/acme/payments-api/actions/runs/9/jobs?per_page=100"
    ]);
    expect(requests.every((r) => r.method === "GET")).toBe(true);
    expect(pr.body?.length).toBe(5000);
    expect(jobs[0].steps[0]).toEqual({ number: 1, name: "Checkout", status: "completed", conclusion: "success" });
  });
});
