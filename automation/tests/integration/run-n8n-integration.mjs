#!/usr/bin/env node
// Imports the workflows into a THROWAWAY n8n instance and runs them against
// mock services (tests/integration/mock-services.mjs). Nothing real is called.
//
// Needs the n8n CLI (same version as production, checked with 2.40.5):
//   npm install -g n8n@2.40.5        (or set N8N_BIN to the n8n executable)
// Run:
//   node automation/tests/integration/run-n8n-integration.mjs [work-dir]
// The work dir (default: a new temp folder) holds the test n8n database; your
// own ~/.n8n is never used.
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import { buildAll, WF, CRED } from '../../scripts/build-workflows.mjs';
import { startMocks } from './mock-services.mjs';
import { parseBody, isWebhookReady, jsonField, messageOf, jsonText, describeProbe } from './http-response.mjs';

const WORK = process.argv[2] || mkdtempSync(join(tmpdir(), 'dc33-n8n-it-'));
// The n8n CLI is started with `node <n8n>/bin/n8n` (no shell), so it can be stopped reliably.
const N8N_JS = process.env.N8N_JS || join(spawnSync('npm', ['root', '-g'], { encoding: 'utf8', shell: process.platform === 'win32' }).stdout.trim(), 'n8n', 'bin', 'n8n');
const PORT = 5690, SVC = 4599, BACKEND = 4598;
const SECRET = 'integration-test-only-secret-0123456789abcdef';
const ENV = {
  ...process.env,
  N8N_USER_FOLDER: WORK,
  N8N_PORT: String(PORT),
  N8N_RUNNERS_BROKER_PORT: '5691',
  N8N_ENCRYPTION_KEY: 'integration-test-encryption-key-not-secret',
  N8N_DIAGNOSTICS_ENABLED: 'false',
  N8N_PERSONALIZATION_ENABLED: 'false',
  N8N_VERSION_NOTIFICATIONS_ENABLED: 'false',
  N8N_BLOCK_ENV_ACCESS_IN_NODE: 'false',
  NODE_FUNCTION_ALLOW_BUILTIN: 'crypto',
  WEBHOOK_URL: `http://127.0.0.1:${PORT}/`,
  BACKEND_BASE_URL: `http://127.0.0.1:${BACKEND}`,
  MACHINE_SIGNING_SECRET: SECRET,
  GROQ_API_BASE_URL: `http://127.0.0.1:${SVC}/groq/openai/v1`,
  GROQ_MODEL: 'test-model',
  GROQ_TIMEOUT_MS: '3000',
  LOKI_URL: `http://127.0.0.1:${SVC}/loki`,
  LOKI_SERVICE_LABEL: 'service',
  PROMETHEUS_URL: `http://127.0.0.1:${SVC}/prom`,
  PROM_SERVICE_LABEL: 'job',
  PROM_QUERY_ERROR_RATE: 'sum(errrate{job="{{service}}"})',
  PROM_THRESHOLD_ERROR_RATE: '0.05',
  GITHUB_API_URL: `http://127.0.0.1:${SVC}/gh`,
  GITHUB_OWNER: 'acme',
  GITHUB_REPO: 'demo',
  RECOVERY_WAIT_SECONDS: '5',
  RECOVERY_MAX_CHECKS: '2',
  REMEDIATION_EXECUTION_MODE: 'simulate',
};

const results = [];
const check = (name, cond, detail) => { results.push({ name, ok: !!cond }); console.log((cond ? '  PASS ' : '  FAIL ') + name + (cond ? '' : '  ' + String(JSON.stringify(detail)).slice(0, 600))); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// Asynchronous on purpose: the mock services run in this process and must keep
// answering while n8n executes a workflow.
const cli = (args) => new Promise((resolve) => {
  const p = spawn(process.execPath, [N8N_JS, ...args], { env: ENV });
  let stdout = '', stderr = '';
  p.stdout.on('data', (d) => (stdout += d));
  p.stderr.on('data', (d) => (stderr += d));
  const t = setTimeout(() => p.kill(), 180000);
  p.on('close', (status) => { clearTimeout(t); resolve({ status, stdout, stderr }); });
});

// ---- harness workflows: webhook -> Execute Workflow(target) -> respond with its output
function harness(key, target) {
  return {
    id: ('dc33it' + key + 'xxxxxxxxxx').slice(0, 16),
    name: 'IT harness ' + key,
    active: false,
    settings: { executionOrder: 'v1', callerPolicy: 'workflowsFromSameOwner' },
    connections: { Webhook: { main: [[{ node: 'Unwrap body', type: 'main', index: 0 }]] }, 'Unwrap body': { main: [[{ node: 'Run target', type: 'main', index: 0 }]] } },
    nodes: [
      { id: randomUUID(), name: 'Webhook', type: 'n8n-nodes-base.webhook', typeVersion: 2, position: [0, 0], webhookId: randomUUID(), parameters: { httpMethod: 'POST', path: 'it-' + key, responseMode: 'lastNode', responseData: 'allEntries', options: {} } },
      { id: randomUUID(), name: 'Unwrap body', type: 'n8n-nodes-base.code', typeVersion: 2, position: [130, 0], parameters: { jsCode: 'return [{ json: $input.first().json.body }];' } },
      { id: randomUUID(), name: 'Run target', type: 'n8n-nodes-base.executeWorkflow', typeVersion: 1.2, position: [260, 0], onError: 'continueRegularOutput', parameters: { source: 'database', workflowId: { __rl: true, value: target.id, mode: 'id' }, workflowInputs: { mappingMode: 'defineBelow', value: {}, matchingColumns: [], schema: [], attemptToConvertTypes: false, convertFieldsToString: true }, mode: 'once', options: { waitForSubWorkflow: true } } },
    ],
  };
}
const HARNESS = { logs: WF.logs, metrics: WF.metrics, deploys: WF.deploys, rca: WF.rca, recovery: WF.recovery, postmortem: WF.postmortem };

async function post(path, body, headers = {}) {
  const raw = typeof body === 'string' ? body : JSON.stringify(body);
  const res = await fetch(`http://127.0.0.1:${PORT}/webhook/${path}`, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: raw });
  const text = await res.text().catch(() => '');
  // Invalid JSON keeps the raw text; an empty body is undefined. Read fields
  // with jsonField()/messageOf(), never r.json.<field> directly.
  return { status: res.status, json: parseBody(text) };
}
const first = (r) => (Array.isArray(r.json) ? r.json[0] : r.json) || {};
const signed = (body, { path = '/webhook/remediation', ts = Math.floor(Date.now() / 1000), nonce = randomBytes(18).toString('base64url'), secret = SECRET } = {}) => {
  const raw = JSON.stringify(body);
  const sig = 'sha256=' + createHmac('sha256', secret).update([ts, nonce, 'POST', path, raw].join('.'), 'utf8').digest('hex');
  return { raw, headers: { 'X-DC-Timestamp': String(ts), 'X-DC-Nonce': nonce, 'X-DC-Signature': sig } };
};

async function main() {
  console.log('n8n integration test, work dir: ' + WORK);
  const version = (await cli(['--version'])).stdout.trim().split(String.fromCharCode(10)).pop().trim();
  console.log('n8n version: ' + version);
  const mocks = startMocks({ servicesPort: SVC, backendPort: BACKEND, secret: SECRET });
  const setScenario = (s) => Object.assign(mocks.scenario, { groq: 'ok', loki: 'errors', prom: 'abnormal', recovery: 'recovered', github: 'recent' }, s);
  const takeCalls = () => mocks.calls.splice(0);

  // ---- import
  const wfDir = join(WORK, 'import');
  mkdirSync(wfDir, { recursive: true });
  const all = buildAll().map((w) => w.json);
  for (const [key, target] of Object.entries(HARNESS)) all.push(harness(key, target));
  all.forEach((w) => writeFileSync(join(wfDir, w.id + '.json'), JSON.stringify(w)));
  writeFileSync(join(WORK, 'creds.json'), JSON.stringify([
    { id: CRED.groq.id, name: CRED.groq.name, type: 'httpHeaderAuth', data: { name: 'Authorization', value: 'Bearer test-groq-key' } },
    { id: CRED.github.id, name: CRED.github.name, type: 'httpHeaderAuth', data: { name: 'Authorization', value: 'Bearer test-gh-token' } },
    { id: CRED.alertmanager.id, name: CRED.alertmanager.name, type: 'httpHeaderAuth', data: { name: 'Authorization', value: 'Bearer test-alert-token' } },
  ]));
  let r = await cli(['import:credentials', '--input=' + join(WORK, 'creds.json')]);
  check('import:credentials', r.status === 0, r.stderr || r.stdout);
  r = await cli(['import:workflow', '--separate', '--input=' + wfDir]);
  check('import:workflow (10 workflows + ' + Object.keys(HARNESS).length + ' harnesses)', r.status === 0, (r.stderr || '') + (r.stdout || ''));

  // ---- 00 Groq test (manual trigger) via the CLI
  console.log('\n00 Groq Connection Test');
  for (const [scenario, expect] of [['ok', 'PASS'], ['auth', 'auth'], ['rate_limited', 'rate_limited'], ['slow', 'timeout'], ['garbage', 'invalid_response'], ['bad_model', 'not_found']]) {
    setScenario({ groq: scenario });
    r = await cli(['execute', '--id=' + WF.groq.id, '--rawOutput']);
    const out = (r.stdout || '') + (r.stderr || '');
    const got = expect === 'PASS' ? /"result":\s*"PASS"/.test(out) : new RegExp('"failure":\\s*"' + expect + '"').test(out) && /"result":\s*"FAIL"/.test(out);
    check('00 groq=' + scenario + ' -> ' + expect, got, out.slice(-800));
  }

  for (const w of all) {
    r = await cli(['publish:workflow', '--id=' + w.id]);
    if (r.status !== 0) check('publish ' + w.id, false, (r.stderr || r.stdout).slice(-400));
  }

  // ---- start the server
  const server = spawn(process.execPath, [N8N_JS, 'start'], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
  let log = '';
  server.stdout.on('data', (d) => (log += d));
  server.stderr.on('data', (d) => (log += d));
  let up = false;
  for (let i = 0; i < 90 && !up; i++) { await sleep(2000); try { up = (await fetch(`http://127.0.0.1:${PORT}/healthz`)).ok; } catch {} }
  // Published webhooks are registered some seconds after /healthz is up.
  // Ready = the harness webhook answers 2xx. 404 (not registered yet) and 503
  // ("Database is not ready") are NOT ready.
  let ready = false;
  let lastProbe = null;
  for (let i = 0; i < 60 && up && !ready; i++) {
    const res = await fetch(`http://127.0.0.1:${PORT}/webhook/it-logs`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' }).catch(() => null);
    lastProbe = res ? { status: res.status, json: parseBody(await res.text().catch(() => '')) } : null;
    if (lastProbe) lastProbe.message = messageOf(lastProbe);
    ready = isWebhookReady(lastProbe);
    if (!ready) await sleep(2000);
  }
  check('n8n server started and webhooks registered', up && ready, 'last probe: ' + describeProbe(lastProbe) + '\n' + log.slice(-1500));
  if (!up || !ready) return finish(server, mocks);

  const ctx = { incident_id: null, service_name: 'checkout-api', alert_name: 'HighErrorRate', severity: 'critical', started_at: '2026-11-08T10:00:00Z' };

  console.log('\n02 Log Analysis');
  for (const [loki, status] of [['errors', 'evidence_found'], ['empty', 'no_evidence'], ['down', 'unavailable'], ['bad_query', 'query_rejected']]) {
    setScenario({ loki });
    const o = first(await post('it-logs', ctx));
    check('02 loki=' + loki + ' -> ' + status, o.status === status && o.source === 'logs', o);
    if (loki === 'errors') check('02 secrets in log lines are redacted', !jsonText(o).includes('abcd1234secret'), o.evidence);
  }
  check('02 invalid input -> invalid_input', first(await post('it-logs', { ...ctx, service_name: 'bad name"}' })).status === 'invalid_input');

  console.log('\n03 Metrics Analysis');
  for (const [prom, status] of [['abnormal', 'evidence_found'], ['normal', 'no_evidence'], ['missing', 'unavailable'], ['down', 'unavailable']]) {
    setScenario({ prom });
    const o = first(await post('it-metrics', ctx));
    check('03 prom=' + prom + ' -> ' + status, o.status === status, o);
    if (prom === 'abnormal') check('03 error_rate and cpu flagged abnormal', jsonText(o.findings).includes('error_rate is abnormal') && jsonText(o.findings).includes('cpu is abnormal'), o.findings);
  }

  console.log('\n04 Deployment Correlation');
  for (const [github, status] of [['recent', 'evidence_found'], ['none', 'no_evidence'], ['auth', 'unavailable']]) {
    setScenario({ github });
    const o = first(await post('it-deploys', ctx));
    check('04 github=' + github + ' -> ' + status, o.status === status, o);
    if (github === 'recent') check('04 deployment 501 found 15 min before', (o.evidence || []).some((e) => e.ref === '501' && e.minutes_before_incident === 15 && e.type === 'deployment'), o.evidence);
    if (github === 'auth') check('04 auth error reported as auth', o.error && o.error.kind === 'auth', o.error);
  }

  console.log('\n05 Root Cause Analysis');
  setScenario({}); takeCalls();
  let o = first(await post('it-rca', ctx));
  check('05 all evidence -> analysis_ready', o.status === 'analysis_ready' && o.rca && o.rca.recommended_action === 'rollback' && o.requires_human_review === true, o);
  check('05 no incident_id -> not stored (BD-1)', o.stored === false && o.store_error && o.store_error.kind === 'blocked', o.store_error);
  o = first(await post('it-rca', { ...ctx, incident_id: '22222222-2222-4222-8222-222222222222', investigation_id: '66666666-6666-4666-8666-666666666666' }));
  const storeCall = takeCalls().find((c) => c.port === 'backend');
  check('05 store call is HMAC-signed and accepted by the signature check', storeCall && storeCall.auth === 'ok' && storeCall.path === '/api/machine/investigations/66666666-6666-4666-8666-666666666666/analysis', storeCall);
  check('05 store endpoint missing -> not_implemented (BD-2)', o.stored === false && o.store_error && o.store_error.kind === 'not_implemented', o);
  setScenario({ loki: 'down' });
  o = first(await post('it-rca', ctx));
  check('05 partial evidence (Loki down) -> analysis_ready, partial', o.status === 'analysis_ready' && o.partial_evidence === true, o);
  setScenario({ loki: 'empty', prom: 'normal', github: 'none' }); takeCalls();
  o = first(await post('it-rca', ctx));
  check('05 no evidence -> no_evidence, Groq NOT called', o.status === 'no_evidence' && !takeCalls().some((c) => c.path.includes('groq')), o);
  setScenario({ loki: 'down', prom: 'down', github: 'auth' });
  o = first(await post('it-rca', ctx));
  check('05 all sources down -> sources_unavailable', o.status === 'sources_unavailable', o);
  setScenario({ groq: 'garbage' });
  o = first(await post('it-rca', ctx));
  check('05 invalid Groq JSON -> invalid_ai_response', o.status === 'invalid_ai_response', o);
  setScenario({ groq: 'bad_action' });
  o = first(await post('it-rca', ctx));
  check('05 unsafe recommended_action rejected by schema', o.status === 'invalid_ai_response' && /recommended_action/.test(o.error && o.error.message), o);

  console.log('\n01 Alert Intake');
  setScenario({});
  const alert = (await import('node:fs')).readFileSync(new URL('../../test-data/sample-alert.json', import.meta.url), 'utf8');
  const auth = { Authorization: 'Bearer test-alert-token' };
  r = await post('alertmanager', alert, {});
  check('01 missing token -> 401/403', r.status === 401 || r.status === 403, r);
  r = await post('alertmanager', alert, auth);
  check('01 valid alert -> 202, 1 new', r.status === 202 && jsonField(r, 'new_alerts') === 1, r);
  // n8n saves static data when an execution ENDS, so the repeat is sent after
  // the first execution finished (Alertmanager repeats after repeat_interval).
  await sleep(4000);
  r = await post('alertmanager', alert, auth);
  check('01 repeated alert -> duplicate, 0 new', r.status === 202 && jsonField(r, 'new_alerts') === 0 && jsonField(r, 'duplicate_alerts') === 1, r);
  r = await post('alertmanager', { alerts: [] }, auth);
  check('01 invalid payload -> 400', r.status === 400, r);
  r = await post('alertmanager', JSON.parse(alert.replace('"status": "firing",\n      "labels"', '"status": "resolved",\n      "labels"').replace('a1b2c3d4e5f60718', 'ffff000011112222')), auth);
  check('01 resolved alert -> 202, no incident', r.status === 202 && jsonField(r, 'resolved_alerts') === 1 && jsonField(r, 'new_alerts') === 0, r);

  console.log('\n06 Remediation');
  const RUN = '11111111-1111-4111-8111-111111111111', INC = '22222222-2222-4222-8222-222222222222';
  setScenario({}); takeCalls();
  let s = signed({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart', request_payload: { service_name: 'checkout-api' } });
  r = await post('remediation', s.raw, s.headers);
  check('06 approved run -> 202 accepted', r.status === 202 && jsonField(r, 'accepted') === true, r);
  // Sent while the first execution is still running: n8n's nonce store (static
  // data) is not saved yet, so the backend's state check is what stops it.
  const replay = await post('remediation', s.raw, s.headers);
  check('06 replayed request -> 409 (n8n nonce or backend state)', replay.status === 409, replay);
  await sleep(14000);
  let calls = takeCalls();
  const backendCalls = calls.filter((c) => c.port === 'backend');
  check('06 backend start called (signed)', backendCalls.some((c) => c.path.endsWith('/start') && c.auth === 'ok'), backendCalls);
  check('06 backend complete called with status success + simulated result', backendCalls.some((c) => c.path.endsWith('/complete') && c.body && c.body.status === 'success' && c.body.result && c.body.result.simulated === true), backendCalls);
  check('06 replay did not execute the run twice (one complete call)', backendCalls.filter((c) => c.path.endsWith('/complete')).length === 1, backendCalls.map((c) => c.path));
  s = signed({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart', request_payload: { service_name: 'checkout-api' } }, { nonce: s.headers['X-DC-Nonce'] });
  r = await post('remediation', s.raw, s.headers);
  check('06 nonce reused after the first execution ended -> 409 from n8n (backend not called)', r.status === 409 && /Replayed/.test(messageOf(r)) && !takeCalls().some((c) => c.port === 'backend'), r);
  check('07 recovery checked Prometheus and tried to store (BD-3 route)', calls.some((c) => c.path.includes('/prom/')) && backendCalls.some((c) => c.path === '/api/machine/recovery-checks' && c.auth === 'ok'), calls.map((c) => c.path));
  check('08 postmortem generated after recovery (Groq called)', calls.some((c) => c.path.includes('/groq/')), calls.map((c) => c.path));
  s = signed({ playbook_run_id: '33333333-3333-4333-8333-333333333333', incident_id: INC, action_type: 'rollback' });
  r = await post('remediation', s.raw, s.headers);
  check('06 run not approved -> 409 refused, nothing executed', r.status === 409 && /not approved/.test(messageOf(r)), r);
  s = signed({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart' }, { secret: 'wrong-secret-wrong-secret-wrong-secret!!' });
  r = await post('remediation', s.raw, s.headers);
  check('06 invalid HMAC -> 401', r.status === 401, r);
  s = signed({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart' }, { ts: Math.floor(Date.now() / 1000) - 600 });
  r = await post('remediation', s.raw, s.headers);
  check('06 stale timestamp -> 401', r.status === 401, r);
  s = signed({ playbook_run_id: RUN, incident_id: INC, action_type: 'reboot' });
  r = await post('remediation', s.raw, s.headers);
  check('06 unsupported action -> 400', r.status === 400, r);
  s = signed({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart', command: 'rm -rf /' });
  r = await post('remediation', s.raw, s.headers);
  check('06 extra fields (e.g. a command) -> 400', r.status === 400, r);
  takeCalls();
  s = signed({ playbook_run_id: '55555555-5555-4555-8555-555555555555', incident_id: INC, action_type: 'scale' });
  r = await post('remediation', s.raw, s.headers);
  await sleep(3000);
  calls = takeCalls().filter((c) => c.port === 'backend');
  check('06 action differs from approved playbook -> 409 and run completed as failed', r.status === 409 && calls.some((c) => c.path.endsWith('/complete') && c.body && c.body.status === 'failed'), { r, calls });

  console.log('\n07 Recovery Check');
  const rc = { incident_id: INC, playbook_run_id: RUN, service_name: 'checkout-api', action_type: 'restart', simulated: true };
  setScenario({ recovery: 'recovered' });
  o = first(await post('it-recovery', rc));
  check('07 recovered -> status recovered (db healthy)', o.status === 'recovered' && o.db_status === 'healthy' && o.checks_performed === 1, o);
  check('07 store route missing -> not_implemented (BD-3)', o.stored === false && o.store_error && o.store_error.kind === 'not_implemented', o.store_error);
  setScenario({ recovery: 'not' });
  o = first(await post('it-recovery', rc));
  check('07 not recovered after max checks -> not_recovered (2 checks)', o.status === 'not_recovered' && o.checks_performed === 2, o);
  setScenario({ recovery: 'unavailable' });
  o = first(await post('it-recovery', rc));
  check('07 metrics missing -> unable_to_verify', o.status === 'unable_to_verify', o);
  o = first(await post('it-recovery', { ...rc, service_name: null }));
  check('07 unknown service -> unable_to_verify, no wait', o.status === 'unable_to_verify' && o.checks_performed === 0, o);

  console.log('\n08 Postmortem');
  setScenario({});
  o = first(await post('it-postmortem', { incident_id: INC, playbook_run_id: RUN, status: 'recovered', checks_performed: 1, evidence: [], action_type: 'restart', simulated_remediation: true }));
  check('08 complete context -> draft_ready, not stored (BD-4)', o.status === 'draft_ready' && o.postmortem && o.stored === false && o.store_error.kind === 'blocked', o);
  o = first(await post('it-postmortem', { incident_id: INC }));
  check('08 missing context -> insufficient_context, no Groq', o.status === 'insufficient_context', o);
  setScenario({ groq: 'rate_limited' });
  o = first(await post('it-postmortem', { incident_id: INC, status: 'recovered' }));
  check('08 Groq failure -> ai_unavailable', o.status === 'ai_unavailable' && o.error.kind === 'rate_limited', o);

  finish(server, mocks);
}

function finish(server, mocks) {
  if (server) server.kill();
  mocks.close();
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
  if (failed.length) { console.log('FAILED:\n - ' + failed.map((f) => f.name).join('\n - ')); process.exitCode = 1; }
  setTimeout(() => process.exit(), 1500);
}

main().catch((e) => { console.error(e); process.exit(1); });
