// Workflow 04 – Deployment Correlation: GitHub + local releases (release.sh).
// Run: cd automation && node --test tests/deployment-correlation.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { runCodeNode } from './code-node-harness.mjs';
import { buildAll, WF } from '../scripts/build-workflows.mjs';

const SECRET = 'unit-test-only-secret-0123456789abcdefghij';
const INC = '22222222-2222-4222-8222-222222222222';
const STARTED = '2026-11-18T20:00:00.000Z';
const input = { incident_id: INC, service_name: 'sample-app', alert_name: 'HighErrorRate', severity: 'high', started_at: STARTED };
const GITHUB = { GITHUB_OWNER: 'example-org', GITHUB_REPO: 'example-repo' };
const BACKEND = { MACHINE_SIGNING_SECRET: SECRET, BACKEND_BASE_URL: 'http://backend:3000' };
const minutesBefore = (m) => new Date(Date.parse(STARTED) - m * 60000).toISOString();

const build = (env) => runCodeNode('04-deployment-correlation/build-requests.js', { items: [input], env });
const sign = (env, reqs, githubResponses = []) =>
  runCodeNode('04-deployment-correlation/sign-local-releases.js', { items: githubResponses.length ? githubResponses : reqs, env, nodes: { 'Build GitHub requests': reqs } });
const correlate = (reqs, signed, localResponse, env = {}) =>
  runCodeNode('04-deployment-correlation/correlate.js', { items: [localResponse || signed], env, nodes: { 'Build GitHub requests': reqs, 'Sign local releases request': [signed] } });

const releases = (...list) => ({ statusCode: 200, body: { success: true, data: { deployments: list } } });
const release = (version, minutes) => ({ id: 'd-' + version, service_name: 'sample-app', version, provider: 'local', status: 'success', completed_at: minutesBefore(minutes) });
const commits = (...list) => ({ statusCode: 200, body: list.map(([sha, minutes]) => ({ sha, html_url: null, commit: { message: 'change ' + sha, committer: { date: minutesBefore(minutes) } } })) });
const runs = { statusCode: 200, body: { workflow_runs: [] } };

test('04: without GitHub settings the workflow continues with one { kind: none } item (no early stop)', async () => {
  const out = await build({});
  assert.equal(out.length, 1);
  assert.equal(out[0].skip, false);
  assert.equal(out[0].kind, 'none');
  assert.match(out[0].github_reason, /GITHUB_OWNER/);
  assert.equal(out[0].window.until, STARTED);
});

test('04: invalid input still returns the skipped result', async () => {
  const out = await build({ ...GITHUB, ...BACKEND });
  assert.equal(out.length, 2);
  const bad = await runCodeNode('04-deployment-correlation/build-requests.js', { items: [{ ...input, service_name: 'bad name' }], env: GITHUB });
  assert.equal(bad[0].skip, true);
  assert.equal(bad[0].result.status, 'invalid_input');
});

test('04: the local releases request is signed over the exact path with the query string', async () => {
  const reqs = await build({});
  const [signed] = await sign(BACKEND, reqs);
  assert.equal(signed.skip_local, false);
  assert.equal(signed.github_configured, false);
  const expectedPath = '/api/machine/deployments?service_name=sample-app&since=' + reqs[0].window.since + '&until=' + STARTED;
  assert.equal(signed.request.path, expectedPath);
  assert.equal(signed.request.url, 'http://backend:3000' + expectedPath);
  assert.equal(signed.request.method, 'GET');
  const h = signed.request.headers;
  const expected = 'sha256=' + createHmac('sha256', SECRET).update([h['X-DC-Timestamp'], h['X-DC-Nonce'], 'GET', expectedPath, ''].join('.'), 'utf8').digest('hex');
  assert.equal(h['X-DC-Signature'], expected);
});

test('04: GitHub not configured + a local release 4 min before -> evidence for rollback', async () => {
  const reqs = await build({});
  const [signed] = await sign(BACKEND, reqs);
  const [result] = await correlate(reqs, signed, releases(release('v2', 4)));
  assert.equal(result.status, 'evidence_found');
  assert.equal(result.confidence, 0.7);
  assert.match(result.summary, /new release \(v2\) went out 4 min before/);
  assert.match(result.findings[0], /Release sample-app v2 went out 4 min before the incident\. .*rollback/);
  assert.deepEqual(result.evidence[0], { type: 'deployment', source: 'local', ref: 'v2', timestamp: minutesBefore(4), value: 'local release sample-app v2 (success)', minutes_before_incident: 4, url: null });
  assert.equal(result.error.kind, 'partial');
  assert.match(result.error.message, /GitHub repository is not configured/);
});

test('04: a local release outside the suspect window is not a suspect', async () => {
  const reqs = await build({});
  const [signed] = await sign(BACKEND, reqs);
  const [result] = await correlate(reqs, signed, releases(release('v1', 180)));
  assert.equal(result.status, 'no_evidence');
  assert.equal(result.confidence, 0.2);
  assert.equal(result.evidence[0].minutes_before_incident, 180);
});

test('04: no releases and no GitHub -> no_evidence', async () => {
  const reqs = await build({});
  const [signed] = await sign(BACKEND, reqs);
  const [result] = await correlate(reqs, signed, releases());
  assert.equal(result.status, 'no_evidence');
});

test('04: neither GitHub nor backend signing configured -> not_configured', async () => {
  const reqs = await build({});
  const [signed] = await sign({}, reqs);
  assert.equal(signed.skip_local, true);
  const [result] = await correlate(reqs, signed, null);
  assert.equal(result.status, 'not_configured');
  assert.match(result.error.message, /GitHub repository is not configured/);
  assert.match(result.error.message, /MACHINE_SIGNING_SECRET/);
});

test('04: GitHub down + a recent local release -> still evidence_found', async () => {
  const reqs = await build({ ...GITHUB });
  const down = { statusCode: 503, body: { message: 'unavailable' } };
  const [signed] = await sign(BACKEND, reqs, [down, down]);
  assert.equal(signed.github_responses.length, 2);
  const [result] = await correlate(reqs, signed, releases(release('v2', 6)));
  assert.equal(result.status, 'evidence_found');
  assert.equal(result.evidence[0].source, 'local');
  assert.match(result.error.message, /commits: server_error/);
});

test('04: GitHub works + backend fails -> GitHub evidence, with a note that local releases were not read', async () => {
  const reqs = await build({ ...GITHUB });
  const [signed] = await sign(BACKEND, reqs, [commits(['abc123', 10]), runs]);
  const [result] = await correlate(reqs, signed, { statusCode: 500, body: { message: 'boom' } });
  assert.equal(result.status, 'evidence_found');
  assert.equal(result.confidence, 0.45);
  assert.equal(result.evidence[0].source, 'github');
  assert.ok(result.findings.some((f) => /Local releases could not be read/.test(f)));
});

test('04: a local release ranks before a GitHub commit at the same distance; both sources fail -> unavailable', async () => {
  const reqs = await build({ ...GITHUB });
  const [signed] = await sign(BACKEND, reqs, [commits(['abc123', 5]), runs]);
  const [result] = await correlate(reqs, signed, releases(release('v2', 5)));
  assert.equal(result.evidence[0].source, 'local');
  assert.equal(result.confidence, 0.7);

  const down = { statusCode: 503, body: {} };
  const [signed2] = await sign(BACKEND, reqs, [down, down]);
  const [result2] = await correlate(reqs, signed2, { statusCode: 503, body: {} });
  assert.equal(result2.status, 'unavailable');
});

test('04 workflow: GitHub credential only on the GitHub node; local releases are a signed GET; no-GitHub path reaches the local check', () => {
  const wf = buildAll().find((x) => x.meta.id === WF.deploys.id).json;
  const node = (name) => wf.nodes.find((n) => n.name === name);
  const withCredentials = wf.nodes.filter((n) => n.credentials).map((n) => n.name);
  assert.deepEqual(withCredentials, ['GitHub API']);
  const local = node('Backend: local releases');
  assert.equal(local.parameters.method, 'GET');
  assert.equal(local.parameters.url, '={{ $json.request.url }}');
  assert.deepEqual(local.parameters.headerParameters.parameters.map((h) => h.name), ['X-DC-Timestamp', 'X-DC-Nonce', 'X-DC-Signature']);
  const out = (from, idx) => (wf.connections[from].main[idx] || []).map((l) => l.node);
  assert.deepEqual(out('GitHub configured?', 0), ['GitHub API']);
  assert.deepEqual(out('GitHub configured?', 1), ['Sign local releases request']);
  assert.deepEqual(out('GitHub API', 0), ['Sign local releases request']);
  assert.deepEqual(out('Read local releases?', 0), ['Backend: local releases']);
  assert.deepEqual(out('Read local releases?', 1), ['Correlate changes']);
  assert.deepEqual(out('Backend: local releases', 0), ['Correlate changes']);
});
