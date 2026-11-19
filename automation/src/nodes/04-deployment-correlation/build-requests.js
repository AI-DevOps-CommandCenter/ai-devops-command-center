// Workflow 04 – Deployment Correlation (owner: Tharindu)
// Node: "Build GitHub requests". Two sources of changes before the incident:
//   - GitHub REST API: recent commits and GitHub Actions workflow runs of
//     GITHUB_OWNER/GITHUB_REPO (read-only token), when configured;
//   - local releases recorded by monitoring/scripts/release.sh, read from the
//     backend in "Sign local releases request" (always tried).
// Without GitHub settings one item { kind: 'none' } is returned, so the local
// release check still runs.
//#include lib/common.js

const env = $env;
const input = readInvestigationInput($input.first().json);
const ctx = input.ctx;

if (!input.ok) {
  return [{ json: { skip: true, result: investigationResult('deployments', ctx, { status: 'invalid_input', error: { kind: 'invalid_input', message: input.error } }) } }];
}

const hours = envInt(env, 'DEPLOY_LOOKBACK_HOURS', 24, 1, 168);
const until = new Date(ctx.started_at);
const since = new Date(until.getTime() - hours * 3600000);
const window = { since: since.toISOString(), until: until.toISOString() };

const owner = env.GITHUB_OWNER;
const repo = env.GITHUB_REPO;
if (!owner || !repo || !/^[A-Za-z0-9_.-]{1,100}$/.test(owner) || !/^[A-Za-z0-9_.-]{1,100}$/.test(repo)) {
  return [{ json: { skip: false, ctx, kind: 'none', window, github_reason: 'GitHub repository is not configured (GITHUB_OWNER, GITHUB_REPO).' } }];
}

const api = String(env.GITHUB_API_URL || 'https://api.github.com').replace(/\/+$/, '');
const base = api + '/repos/' + encodeURIComponent(owner) + '/' + encodeURIComponent(repo);
const timeout = envInt(env, 'GITHUB_TIMEOUT_MS', 15000, 1000, 60000);

return [
  { json: { skip: false, ctx, kind: 'commits', window, timeout_ms: timeout, url: base + '/commits?' + toQuery({ since: window.since, until: window.until, per_page: '30' }) } },
  { json: { skip: false, ctx, kind: 'workflow_runs', window, timeout_ms: timeout, url: base + '/actions/runs?' + toQuery({ created: '>=' + window.since, per_page: '30' }) } },
];
