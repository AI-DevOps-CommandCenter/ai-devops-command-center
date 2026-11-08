// Workflow 04 – Deployment Correlation (owner: Tharindu)
// Node: "Build GitHub requests". The project has no deployment records yet,
// so changes are taken from the GitHub REST API: recent commits and recent
// GitHub Actions workflow runs of GITHUB_OWNER/GITHUB_REPO (read-only token).
//#include lib/common.js

const env = $env;
const input = readInvestigationInput($input.first().json);
const ctx = input.ctx;

if (!input.ok) {
  return [{ json: { skip: true, result: investigationResult('deployments', ctx, { status: 'invalid_input', error: { kind: 'invalid_input', message: input.error } }) } }];
}
const owner = env.GITHUB_OWNER;
const repo = env.GITHUB_REPO;
if (!owner || !repo || !/^[A-Za-z0-9_.-]{1,100}$/.test(owner) || !/^[A-Za-z0-9_.-]{1,100}$/.test(repo)) {
  return [{ json: { skip: true, result: investigationResult('deployments', ctx, { status: 'not_configured', summary: 'GitHub repository is not configured.', error: { kind: 'not_configured', message: 'Set GITHUB_OWNER and GITHUB_REPO in the n8n environment.' } }) } }];
}

const api = String(env.GITHUB_API_URL || 'https://api.github.com').replace(/\/+$/, '');
const hours = envInt(env, 'DEPLOY_LOOKBACK_HOURS', 24, 1, 168);
const until = new Date(ctx.started_at);
const since = new Date(until.getTime() - hours * 3600000);
const base = api + '/repos/' + encodeURIComponent(owner) + '/' + encodeURIComponent(repo);
const timeout = envInt(env, 'GITHUB_TIMEOUT_MS', 15000, 1000, 60000);
const window = { since: since.toISOString(), until: until.toISOString() };

return [
  { json: { skip: false, ctx, kind: 'commits', window, timeout_ms: timeout, url: base + '/commits?' + toQuery({ since: window.since, until: window.until, per_page: '30' }) } },
  { json: { skip: false, ctx, kind: 'workflow_runs', window, timeout_ms: timeout, url: base + '/actions/runs?' + toQuery({ created: '>=' + window.since, per_page: '30' }) } },
];
