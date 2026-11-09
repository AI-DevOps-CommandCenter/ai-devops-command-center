// Trimmed GitHub REST API payloads (shapes from the public API docs).
// Synthetic data only.

export function repoFixture(owner = "acme", name = "payments-api") {
  return {
    id: 1,
    name,
    full_name: `${owner}/${name}`,
    owner: { login: owner, id: 2 },
    private: true,
    html_url: `https://github.com/${owner}/${name}`,
    description: "Payments service",
    default_branch: "main",
    open_issues_count: 4,
    pushed_at: "2026-11-08T09:00:00Z",
    updated_at: "2026-11-08T09:00:00Z",
    permissions: { admin: false },
    node_id: "R_x"
  };
}

export function commitFixture(sha: string, message: string) {
  return {
    sha,
    html_url: `https://github.com/acme/payments-api/commit/${sha}`,
    commit: {
      message,
      author: { name: "Dev One", email: "dev.one@example.test", date: "2026-11-08T08:45:00Z" },
      committer: { name: "Dev One", email: "dev.one@example.test", date: "2026-11-08T08:45:00Z" }
    },
    author: { login: "devone", id: 10 },
    committer: { login: "devone", id: 10 }
  };
}

export function pullFixture(number: number, overrides: Record<string, unknown> = {}) {
  return {
    number,
    title: "Tune DB pool settings",
    state: "open",
    draft: false,
    merged_at: null,
    closed_at: null,
    created_at: "2026-11-07T08:00:00Z",
    updated_at: "2026-11-08T08:00:00Z",
    html_url: `https://github.com/acme/payments-api/pull/${number}`,
    user: { login: "devone" },
    head: { ref: "feature/pool", sha: "abc" },
    base: { ref: "main", sha: "def" },
    ...overrides
  };
}

export function runFixture(id: number, conclusion: string | null) {
  return {
    id,
    name: "CI",
    run_number: id,
    event: "push",
    status: conclusion ? "completed" : "in_progress",
    conclusion,
    head_branch: "main",
    head_sha: "a91f3c2deadbeef",
    actor: { login: "devone" },
    created_at: "2026-11-08T08:46:00Z",
    updated_at: "2026-11-08T08:50:00Z",
    run_started_at: "2026-11-08T08:46:05Z",
    html_url: `https://github.com/acme/payments-api/actions/runs/${id}`
  };
}

export function jobFixture(id: number) {
  return {
    id,
    name: "build",
    status: "completed",
    conclusion: "failure",
    started_at: "2026-11-08T08:46:10Z",
    completed_at: "2026-11-08T08:49:00Z",
    html_url: `https://github.com/acme/payments-api/actions/runs/1/job/${id}`,
    steps: [
      { number: 1, name: "Checkout", status: "completed", conclusion: "success" },
      { number: 2, name: "Test", status: "completed", conclusion: "failure" }
    ]
  };
}
