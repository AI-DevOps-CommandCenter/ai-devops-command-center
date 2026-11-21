import { GitHubClient, GitHubError, type GitHubClientDeps } from "./github.client.js";
import type { GitHubConfig, GitHubRepoRef } from "./github.config.js";

// Read-only GitHub operations for the mobile Repositories screens
// (S13 repositories, S14 deployment details, S15 failed pipeline job,
// S24 pull request summary).
//
// Responses are mapped to small objects with only the fields those screens
// need. Raw GitHub payloads are never passed through (they contain author
// e-mail addresses and many internal URLs).
//
// Deployment correlation for incidents is NOT done here: n8n workflow 04
// (owner: Tharindu) reads commits and Actions runs directly.

export interface RepositorySummary {
  full_name: string;
  owner: string;
  name: string;
  description: string | null;
  default_branch: string;
  private: boolean;
  html_url: string;
  open_issues_count: number;
  pushed_at: string | null;
  updated_at: string | null;
}

export interface CommitSummary {
  sha: string;
  short_sha: string;
  title: string;
  message: string;
  author_name: string | null;
  author_login: string | null;
  authored_at: string | null;
  html_url: string;
}

export interface PullRequestSummary {
  number: number;
  title: string;
  state: "open" | "closed";
  merged: boolean;
  draft: boolean;
  author_login: string | null;
  head_branch: string | null;
  base_branch: string | null;
  created_at: string | null;
  updated_at: string | null;
  closed_at: string | null;
  merged_at: string | null;
  html_url: string;
}

export interface PullRequestDetail extends PullRequestSummary {
  body: string | null;
  commits: number | null;
  additions: number | null;
  deletions: number | null;
  changed_files: number | null;
  mergeable_state: string | null;
}

export interface WorkflowRunSummary {
  id: number;
  name: string | null;
  run_number: number | null;
  event: string | null;
  status: string | null;
  conclusion: string | null;
  branch: string | null;
  head_sha: string | null;
  actor_login: string | null;
  created_at: string | null;
  updated_at: string | null;
  run_started_at: string | null;
  html_url: string;
}

export interface WorkflowJobSummary {
  id: number;
  name: string;
  status: string | null;
  conclusion: string | null;
  started_at: string | null;
  completed_at: string | null;
  html_url: string | null;
  steps: Array<{ number: number | null; name: string; status: string | null; conclusion: string | null }>;
}

export const PULL_REQUEST_STATES = ["open", "closed", "all"] as const;
export const WORKFLOW_RUN_STATUSES = [
  "queued",
  "in_progress",
  "completed",
  "success",
  "failure",
  "cancelled"
] as const;

const MAX_BODY_LENGTH = 5000;
const MAX_COMMIT_MESSAGE_LENGTH = 2000;

// --- Mapping helpers ---------------------------------------------------------

type Json = Record<string, unknown>;

function isObject(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function str(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function num(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function obj(value: unknown): Json {
  return isObject(value) ? value : {};
}

function truncate(value: string | null, max: number): string | null {
  if (value === null) return null;
  return value.length > max ? `${value.slice(0, max - 3)}...` : value;
}

function invalid(what: string): GitHubError {
  return new GitHubError("invalid_response", `Unexpected GitHub response for ${what}.`);
}

function requireObject(value: unknown, what: string): Json {
  if (!isObject(value)) throw invalid(what);
  return value;
}

function requireArray(value: unknown, what: string): unknown[] {
  if (!Array.isArray(value)) throw invalid(what);
  return value;
}

export function mapRepository(raw: unknown): RepositorySummary {
  const r = requireObject(raw, "repository");
  const fullName = str(r.full_name);
  const name = str(r.name);
  const htmlUrl = str(r.html_url);
  if (!fullName || !name || !htmlUrl) throw invalid("repository");

  return {
    full_name: fullName,
    owner: str(obj(r.owner).login) ?? fullName.split("/")[0],
    name,
    description: str(r.description),
    default_branch: str(r.default_branch) ?? "main",
    private: r.private === true,
    html_url: htmlUrl,
    open_issues_count: num(r.open_issues_count) ?? 0,
    pushed_at: str(r.pushed_at),
    updated_at: str(r.updated_at)
  };
}

export function mapCommit(raw: unknown): CommitSummary {
  const c = requireObject(raw, "commit");
  const sha = str(c.sha);
  const htmlUrl = str(c.html_url);
  if (!sha || !htmlUrl) throw invalid("commit");

  const commit = obj(c.commit);
  const author = obj(commit.author);
  const message = str(commit.message) ?? "";

  return {
    sha,
    short_sha: sha.slice(0, 7),
    title: message.split("\n")[0],
    message: truncate(message, MAX_COMMIT_MESSAGE_LENGTH) ?? "",
    author_name: str(author.name), // the commit e-mail is deliberately not exposed
    author_login: str(obj(c.author).login),
    authored_at: str(author.date),
    html_url: htmlUrl
  };
}

export function mapPullRequest(raw: unknown): PullRequestSummary {
  const p = requireObject(raw, "pull request");
  const number = num(p.number);
  const title = str(p.title);
  const htmlUrl = str(p.html_url);
  if (number === null || title === null || !htmlUrl) throw invalid("pull request");

  const mergedAt = str(p.merged_at);
  return {
    number,
    title,
    state: p.state === "closed" ? "closed" : "open",
    merged: p.merged === true || mergedAt !== null,
    draft: p.draft === true,
    author_login: str(obj(p.user).login),
    head_branch: str(obj(p.head).ref),
    base_branch: str(obj(p.base).ref),
    created_at: str(p.created_at),
    updated_at: str(p.updated_at),
    closed_at: str(p.closed_at),
    merged_at: mergedAt,
    html_url: htmlUrl
  };
}

export function mapPullRequestDetail(raw: unknown): PullRequestDetail {
  const p = requireObject(raw, "pull request");
  return {
    ...mapPullRequest(p),
    body: truncate(str(p.body), MAX_BODY_LENGTH),
    commits: num(p.commits),
    additions: num(p.additions),
    deletions: num(p.deletions),
    changed_files: num(p.changed_files),
    mergeable_state: str(p.mergeable_state)
  };
}

export function mapWorkflowRun(raw: unknown): WorkflowRunSummary {
  const w = requireObject(raw, "workflow run");
  const id = num(w.id);
  const htmlUrl = str(w.html_url);
  if (id === null || !htmlUrl) throw invalid("workflow run");

  return {
    id,
    name: str(w.name),
    run_number: num(w.run_number),
    event: str(w.event),
    status: str(w.status),
    conclusion: str(w.conclusion),
    branch: str(w.head_branch),
    head_sha: str(w.head_sha),
    actor_login: str(obj(w.actor).login),
    created_at: str(w.created_at),
    updated_at: str(w.updated_at),
    run_started_at: str(w.run_started_at),
    html_url: htmlUrl
  };
}

export function mapWorkflowJob(raw: unknown): WorkflowJobSummary {
  const j = requireObject(raw, "workflow job");
  const id = num(j.id);
  const name = str(j.name);
  if (id === null || name === null) throw invalid("workflow job");

  const steps = Array.isArray(j.steps) ? j.steps.filter(isObject) : [];
  return {
    id,
    name,
    status: str(j.status),
    conclusion: str(j.conclusion),
    started_at: str(j.started_at),
    completed_at: str(j.completed_at),
    html_url: str(j.html_url),
    steps: steps.map((s) => ({
      number: num(s.number),
      name: str(s.name) ?? "",
      status: str(s.status),
      conclusion: str(s.conclusion)
    }))
  };
}

// --- Service -------------------------------------------------------------------

export class GitHubService {
  private readonly client: GitHubClient;

  constructor(
    private readonly config: GitHubConfig,
    deps: GitHubClientDeps = {}
  ) {
    this.client = new GitHubClient(config, deps);
  }

  // Returns the configured repository (with its configured spelling) or
  // null when it is not on the allow-list. Names are case-insensitive.
  resolveRepository(owner: string, repo: string): GitHubRepoRef | null {
    const key = `${owner}/${repo}`.toLowerCase();
    return this.config.repositories.find((ref) => `${ref.owner}/${ref.repo}`.toLowerCase() === key) ?? null;
  }

  private repoPath(ref: GitHubRepoRef): string {
    return `/repos/${encodeURIComponent(ref.owner)}/${encodeURIComponent(ref.repo)}`;
  }

  async listRepositories(): Promise<RepositorySummary[]> {
    return Promise.all(this.config.repositories.map((ref) => this.getRepository(ref)));
  }

  async getRepository(ref: GitHubRepoRef): Promise<RepositorySummary> {
    return mapRepository(await this.client.get(this.repoPath(ref)));
  }

  async listCommits(ref: GitHubRepoRef, options: { branch?: string; limit: number }): Promise<CommitSummary[]> {
    const body = await this.client.get(`${this.repoPath(ref)}/commits`, {
      sha: options.branch,
      per_page: options.limit
    });
    return requireArray(body, "commits").map(mapCommit);
  }

  async listPullRequests(
    ref: GitHubRepoRef,
    options: { state: (typeof PULL_REQUEST_STATES)[number]; limit: number }
  ): Promise<PullRequestSummary[]> {
    const body = await this.client.get(`${this.repoPath(ref)}/pulls`, {
      state: options.state,
      sort: "updated",
      direction: "desc",
      per_page: options.limit
    });
    return requireArray(body, "pull requests").map(mapPullRequest);
  }

  async getPullRequest(ref: GitHubRepoRef, number: number): Promise<PullRequestDetail> {
    return mapPullRequestDetail(await this.client.get(`${this.repoPath(ref)}/pulls/${number}`));
  }

  async listWorkflowRuns(
    ref: GitHubRepoRef,
    options: { branch?: string; status?: (typeof WORKFLOW_RUN_STATUSES)[number]; limit: number }
  ): Promise<WorkflowRunSummary[]> {
    const body = await this.client.get(`${this.repoPath(ref)}/actions/runs`, {
      branch: options.branch,
      status: options.status,
      per_page: options.limit
    });
    return requireArray(obj(body).workflow_runs, "workflow runs").map(mapWorkflowRun);
  }

  async listWorkflowRunJobs(ref: GitHubRepoRef, runId: number): Promise<WorkflowJobSummary[]> {
    const body = await this.client.get(`${this.repoPath(ref)}/actions/runs/${runId}/jobs`, { per_page: 100 });
    return requireArray(obj(body).jobs, "workflow jobs").map(mapWorkflowJob);
  }
}

export function isGitHubError(error: unknown): error is GitHubError {
  return error instanceof GitHubError;
}
