import { z } from "zod";

// Configuration for the read-only GitHub integration (owner: M7).
//
// GITHUB_TOKEN          fine-grained token, read-only: Metadata, Contents,
//                       Pull requests, Actions; limited to the listed repositories
// GITHUB_REPOSITORIES   comma-separated allow-list "owner/repo,owner/repo2".
//                       The API only serves these, so the backend token can't
//                       be used to read any other repository.
// GITHUB_API_URL        optional, default https://api.github.com (GitHub
//                       Enterprise: https://<host>/api/v3)
// GITHUB_TIMEOUT_MS     optional, default 10000
// GITHUB_CACHE_TTL_MS   optional, default 30000 (0 disables the cache)
//
// Without GITHUB_TOKEN and GITHUB_REPOSITORIES the GitHub endpoints answer 503.

export interface GitHubRepoRef {
  owner: string;
  repo: string;
}

export interface GitHubConfig {
  token: string;
  repositories: GitHubRepoRef[];
  apiUrl: string;
  timeoutMs: number;
  cacheTtlMs: number;
}

// GitHub owner and repository names: letters, digits, "-", "_" and ".".
export const GITHUB_NAME_PATTERN = /^(?!\.{1,2}$)[A-Za-z0-9_.-]{1,100}$/;

function emptyToUndefined(value: unknown) {
  return typeof value === "string" && value.trim() === "" ? undefined : value;
}

const optionalSchema = z.object({
  GITHUB_API_URL: z.preprocess(
    emptyToUndefined,
    z.url({ protocol: /^https$/ }).default("https://api.github.com")
  ),
  GITHUB_TIMEOUT_MS: z.preprocess(
    emptyToUndefined,
    z.coerce.number().int().min(1000).max(60_000).default(10_000)
  ),
  GITHUB_CACHE_TTL_MS: z.preprocess(
    emptyToUndefined,
    z.coerce.number().int().min(0).max(600_000).default(30_000)
  )
});

export function parseRepositoryList(value: string): GitHubRepoRef[] {
  const refs = value
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0)
    .map((entry) => {
      const [owner, repo, extra] = entry.split("/");
      if (extra !== undefined || !owner || !repo || !GITHUB_NAME_PATTERN.test(owner) || !GITHUB_NAME_PATTERN.test(repo)) {
        throw new Error(
          "Invalid GitHub configuration: GITHUB_REPOSITORIES must be a comma-separated list of owner/repo"
        );
      }
      return { owner, repo };
    });

  // Drop case-insensitive duplicates (GitHub names are case-insensitive).
  const seen = new Set<string>();
  return refs.filter((ref) => {
    const key = `${ref.owner}/${ref.repo}`.toLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export function loadGitHubConfig(env: NodeJS.ProcessEnv = process.env): GitHubConfig | null {
  const token = env.GITHUB_TOKEN?.trim() ?? "";
  const repositories = env.GITHUB_REPOSITORIES?.trim() ?? "";

  if (!token && !repositories) return null;

  // Partly configured: name the missing variable, never a value.
  const missing = [!token && "GITHUB_TOKEN", !repositories && "GITHUB_REPOSITORIES"].filter(Boolean);
  if (missing.length > 0) {
    throw new Error(`Invalid GitHub configuration: missing ${missing.join(", ")}`);
  }

  const parsed = optionalSchema.safeParse(env);
  if (!parsed.success) {
    const problems = parsed.error.issues.map((issue) => `${issue.path.join(".")}: ${issue.message}`).join("; ");
    throw new Error(`Invalid GitHub configuration: ${problems}`);
  }

  const refs = parseRepositoryList(repositories);
  if (refs.length === 0) {
    throw new Error("Invalid GitHub configuration: GITHUB_REPOSITORIES is empty");
  }

  return {
    token,
    repositories: refs,
    apiUrl: parsed.data.GITHUB_API_URL.replace(/\/+$/, ""),
    timeoutMs: parsed.data.GITHUB_TIMEOUT_MS,
    cacheTtlMs: parsed.data.GITHUB_CACHE_TTL_MS
  };
}
