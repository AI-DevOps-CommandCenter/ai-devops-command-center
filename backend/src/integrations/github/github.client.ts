import { httpRequest, HttpRequestError, type FetchLike } from "../http.js";
import type { GitHubConfig } from "./github.config.js";

// Low-level, read-only GitHub REST client.
//
// - Authenticates with the backend's token (never logged or returned).
// - Retries once on timeouts, network errors and 5xx (GET only).
// - Rate limits: when GitHub reports a limit, no further requests are sent
//   until the reset time; callers get `rate_limited` with the wait time.
// - Short in-memory cache so many mobile clients share one GitHub request.

export type GitHubErrorKind =
  | "not_found"
  | "rate_limited"
  | "auth" // the backend token is invalid or lacks access
  | "unavailable" // timeout, network, 5xx or an unexpected rejection
  | "invalid_response";

export class GitHubError extends Error {
  constructor(
    readonly kind: GitHubErrorKind,
    message: string,
    readonly retryAfterMs?: number,
    readonly upstreamStatus?: number
  ) {
    super(message);
    this.name = "GitHubError";
  }
}

export const GITHUB_API_VERSION = "2022-11-28";
const USER_AGENT = "ai-devops-command-center-backend";
const RETRY_DELAY_MS = 300;
const MAX_CACHE_ENTRIES = 200;

export interface GitHubClientDeps {
  fetchImpl?: FetchLike;
  now?: () => number;
  sleep?: (ms: number) => Promise<void>;
}

type QueryValue = string | number | undefined;

export class GitHubClient {
  private readonly cache = new Map<string, { expiresAt: number; body: unknown }>();
  private blockedUntil = 0;
  private readonly now: () => number;
  private readonly sleep: (ms: number) => Promise<void>;

  constructor(
    private readonly config: GitHubConfig,
    private readonly deps: GitHubClientDeps = {}
  ) {
    this.now = deps.now ?? Date.now;
    this.sleep = deps.sleep ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  }

  async get(path: string, query: Record<string, QueryValue> = {}): Promise<unknown> {
    const search = new URLSearchParams();
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined) search.set(key, String(value));
    }
    const pathAndQuery = search.size > 0 ? `${path}?${search.toString()}` : path;

    const cached = this.cache.get(pathAndQuery);
    if (cached && cached.expiresAt > this.now()) return cached.body;

    const waitMs = this.blockedUntil - this.now();
    if (waitMs > 0) {
      throw new GitHubError("rate_limited", "GitHub rate limit reached.", waitMs, 429);
    }

    const body = await this.requestWithRetry(pathAndQuery);

    if (this.config.cacheTtlMs > 0) {
      if (this.cache.size >= MAX_CACHE_ENTRIES) {
        // Map keeps insertion order: drop the oldest entry.
        const oldest = this.cache.keys().next().value;
        if (oldest !== undefined) this.cache.delete(oldest);
      }
      this.cache.set(pathAndQuery, { expiresAt: this.now() + this.config.cacheTtlMs, body });
    }

    return body;
  }

  private async requestWithRetry(pathAndQuery: string): Promise<unknown> {
    for (let attempt = 1; ; attempt += 1) {
      try {
        const response = await httpRequest(`${this.config.apiUrl}${pathAndQuery}`, {
          method: "GET",
          timeoutMs: this.config.timeoutMs,
          fetchImpl: this.deps.fetchImpl,
          now: this.now,
          headers: {
            Accept: "application/vnd.github+json",
            Authorization: `Bearer ${this.config.token}`,
            "X-GitHub-Api-Version": GITHUB_API_VERSION,
            "User-Agent": USER_AGENT
          }
        });

        // Last request of the window: stop before GitHub starts rejecting.
        if (response.headers.get("x-ratelimit-remaining") === "0") {
          const reset = Number(response.headers.get("x-ratelimit-reset"));
          if (Number.isFinite(reset) && reset > 0) this.blockedUntil = reset * 1000;
        }

        return response.body;
      } catch (error) {
        if (!(error instanceof HttpRequestError)) throw error;

        if (error.kind === "rate_limited") {
          const wait = error.retryAfterMs ?? 60_000;
          this.blockedUntil = this.now() + wait;
          console.warn(`GitHub rate limit reached; pausing requests for ${Math.ceil(wait / 1000)} s.`);
          throw new GitHubError("rate_limited", "GitHub rate limit reached.", wait, error.status);
        }

        if (error.retryable && attempt < 2) {
          await this.sleep(RETRY_DELAY_MS);
          continue;
        }

        throw toGitHubError(error);
      }
    }
  }
}

function toGitHubError(error: HttpRequestError): GitHubError {
  switch (error.kind) {
    case "not_found":
      return new GitHubError("not_found", "GitHub resource not found.", undefined, error.status);
    case "auth":
      console.error(`GitHub rejected the backend token (HTTP ${error.status}). Check GITHUB_TOKEN permissions.`);
      return new GitHubError("auth", "GitHub authentication failed.", undefined, error.status);
    default:
      console.error(`GitHub request failed: ${error.kind}${error.status ? ` (HTTP ${error.status})` : ""}.`);
      return new GitHubError("unavailable", "GitHub is unavailable.", error.retryAfterMs, error.status);
  }
}
