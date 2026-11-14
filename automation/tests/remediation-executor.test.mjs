// Workflow 06 executor mode (REMEDIATION_EXECUTION_MODE=executor): the signed
// POST /v1/execute to the playbook executor (infrastructure/playbooks/executor)
// and how its answers become the completion status. Real Code node scripts,
// no n8n. Run: cd automation && node --test tests/remediation-executor.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { createRequire } from 'node:module';
import { runCodeNode } from './code-node-harness.mjs';
import { buildAll, WF } from '../scripts/build-workflows.mjs';

const MACHINE = 'unit-test-only-machine-secret-0123456789ab';
const EXEC = 'unit-test-only-executor-secret-0123456789';
const RUN = '11111111-1111-4111-8111-111111111111';
const INC = '22222222-2222-4222-8222-222222222222';
const ENV = { MACHINE_SIGNING_SECRET: MACHINE, REMEDIATION_EXECUTION_MODE: 'executor', EXECUTOR_URL: 'http://host.docker.internal:9095/', EXECUTOR_SIGNING_SECRET: EXEC };

// Output of "Check start result" -> "Action type" (the database copy of the run).
const started = (action = 'restart', payload = { service_name: 'sample-app' }) => ({
  valid: true, execution_mode: 'executor', execution_available: true, playbook_run_id: RUN, incident_id: INC,
  requested_action: action, action_type: action, request_payload: payload, n8n_execution_id: '1001', started: true,
});

async function execute(action, payload, env = ENV) {
  const wf = buildAll().find((x) => x.meta.id === WF.remediation.id).json;
  const node = wf.nodes.find((n) => n.name === 'Execute: ' + action);
  // Run the generated node code (ACTION already substituted by the builder).
  const fn = new Function('$input', '$env', 'require', 'Buffer', `return (async function () {\n${node.parameters.jsCode}\n})();`);
  const out = await fn({ first: () => ({ json: started(action, payload) }) }, env, createRequire(import.meta.url), Buffer);
  return out[0].json;
}

const checkResult = (input, response) => runCodeNode('06-remediation/check-executor-result.js', {
  items: [response], nodes: { 'Call executor?': [input] },
});

test('06 verify: executor mode is available only when EXECUTOR_URL and a 32+ char secret are set', async () => {
  const body = JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart' });
  const ts = Math.floor(Date.now() / 1000);
  const run = async (env) => {
    const nonce = 'nonce-' + Math.random().toString(36).slice(2, 14) + 'abcdef';
    const sig = 'sha256=' + createHmac('sha256', MACHINE).update([ts, nonce, 'POST', '/webhook/remediation', body].join('.')).digest('hex');
    const [o] = await runCodeNode('06-remediation/verify-request.js', {
      items: [{ headers: { 'x-dc-timestamp': String(ts), 'x-dc-nonce': nonce, 'x-dc-signature': sig }, body: JSON.parse(body) }],
      binary: { data: { data: Buffer.from(body).toString('base64') } }, env,
    });
    return o;
  };
  const ok = await run(ENV);
  assert.equal(ok.execution_mode, 'executor');
  assert.equal(ok.execution_available, true);
  for (const bad of [{ EXECUTOR_URL: '' }, { EXECUTOR_URL: 'ftp://x' }, { EXECUTOR_SIGNING_SECRET: 'short' }, { EXECUTOR_SIGNING_SECRET: undefined }]) {
    const o = await run({ ...ENV, ...bad });
    assert.equal(o.execution_mode, 'disabled', JSON.stringify(bad));
    assert.equal(o.execution_available, false);
  }
  const sim = await run({ ...ENV, REMEDIATION_EXECUTION_MODE: 'simulate' });
  assert.equal(sim.execution_mode, 'simulate');
  assert.equal(sim.execution_available, true);
});

test('06 executor request: exact body, executor secret, path /v1/execute, 90 s timeout', async () => {
  for (const action of ['restart', 'rollback', 'scale', 'circuit_breaker']) {
    const o = await execute(action);
    assert.equal(o.execute_via_executor, true);
    const r = o.request;
    assert.equal(r.method, 'POST');
    assert.equal(r.url, 'http://host.docker.internal:9095/v1/execute');
    assert.equal(r.path, '/v1/execute');
    assert.equal(r.timeout_ms, 90000);
    assert.deepEqual(JSON.parse(r.body), { action, service_name: 'sample-app', playbook_run_id: RUN });
    const h = r.headers;
    const expect = (secret) => 'sha256=' + createHmac('sha256', secret).update([h['X-DC-Timestamp'], h['X-DC-Nonce'], 'POST', '/v1/execute', r.body].join('.')).digest('hex');
    assert.equal(h['X-DC-Signature'], expect(EXEC), 'signed with EXECUTOR_SIGNING_SECRET');
    assert.notEqual(h['X-DC-Signature'], expect(MACHINE), 'not with the backend secret');
    assert.match(h['X-DC-Nonce'], /^[A-Za-z0-9_-]{16,200}$/);
  }
  assert.equal((await execute('restart', undefined, { ...ENV, EXECUTOR_TIMEOUT_MS: '120000' })).request.timeout_ms, 120000);
});

test('06 executor request: never sends a service name that is missing or not a plain name', async () => {
  for (const payload of [{}, { service_name: '' }, { service_name: 'a b' }, { service_name: 'x;rm -rf /' }, null]) {
    const o = await execute('restart', payload);
    assert.equal(o.execute_via_executor, false);
    assert.equal(o.request, undefined);
    assert.equal(o.outcome, 'failed');
    assert.equal(o.result.executed, false);
  }
});

test('06 executor result: only 2xx with executed: true is a success; nothing secret is copied', async () => {
  const input = await execute('restart');
  const ok = await checkResult(input, { statusCode: 200, body: { executed: true, action: 'restart', service_name: 'sample-app', playbook_run_id: RUN, started_at: '2026-11-14T10:00:00Z', finished_at: '2026-11-14T10:00:40Z', detail: 'restarted; /health 200', repeated: false } });
  assert.equal(ok[0].outcome, 'success');
  assert.equal(ok[0].result.executed, true);
  assert.equal(ok[0].result.executor, true);
  assert.equal(ok[0].result.service_name, 'sample-app');
  assert.equal(ok[0].request, undefined);
  assert.equal(ok[0].execute_via_executor, undefined);
  const s = JSON.stringify(ok[0]);
  assert.doesNotMatch(s, new RegExp(input.request.headers['X-DC-Nonce']));
  assert.doesNotMatch(s, /sha256=/);

  const cases = [
    [{ statusCode: 200, body: { executed: true, repeated: true } }, 'success'],
    [{ statusCode: 200, body: { executed: false } }, 'failed'],
    [{ statusCode: 500, body: { executed: false, message: 'health check failed', repeated: true } }, 'failed'],
    [{ statusCode: 500, body: { executed: false, message: 'docker error' } }, 'failed'],
    [{ statusCode: 400, body: { message: 'unexpected field' } }, 'failed'],
    [{ statusCode: 401, body: { message: 'Invalid request signature.' } }, 'failed'],
    [{ statusCode: 403, body: { message: 'service not allowlisted' } }, 'failed'],
    [{ statusCode: 409, body: { message: 'run still executing' } }, 'failed'],
    [{ statusCode: 422, body: { message: 'action not granted' } }, 'failed'],
    [{ statusCode: 503, body: { message: 'not configured' } }, 'failed'],
    [{ error: { message: 'timeout of 90000ms exceeded', code: 'ECONNABORTED' } }, 'failed'],
    [{ error: { message: 'connect ECONNREFUSED 127.0.0.1:9095' } }, 'failed'],
  ];
  for (const [resp, outcome] of cases) {
    const [o] = await checkResult(input, resp);
    assert.equal(o.outcome, outcome, JSON.stringify(resp));
    if (outcome === 'failed') assert.ok(o.result.reason, 'failed results explain why');
  }
  const [timeout] = await checkResult(input, { error: { message: 'timeout', code: 'ETIMEDOUT' } });
  assert.match(timeout.result.reason, /may still have run/);
});

test('06 executor result feeds the existing completion: success -> complete success + recovery check', async () => {
  const input = await execute('restart');
  const [done] = await checkResult(input, { statusCode: 200, body: { executed: true, service_name: 'sample-app' } });
  const [signed] = await runCodeNode('06-remediation/sign-complete.js', { items: [done], env: { MACHINE_SIGNING_SECRET: MACHINE, BACKEND_BASE_URL: 'http://backend:3000' } });
  const body = JSON.parse(signed.request.body);
  assert.equal(body.status, 'success');
  assert.equal(body.n8n_execution_id, '1001');
  assert.equal(body.result.executed, true);
  assert.equal(signed.request.url, 'http://backend:3000/api/machine/playbook-runs/' + RUN + '/complete');
  const [checked] = await runCodeNode('06-remediation/check-complete.js', { items: [{ statusCode: 200, body: { data: {} } }], nodes: { 'Sign complete request': [signed] } });
  assert.equal(checked.check_recovery, true);
  assert.equal(checked.simulated, false);
  assert.equal(checked.service_name, 'sample-app');
});

test('06 workflow routing: Execute -> Call executor? -> Executor: execute -> Check executor result -> Sign complete request', () => {
  const wf = buildAll().find((x) => x.meta.id === WF.remediation.id).json;
  const node = (name) => wf.nodes.find((n) => n.name === name);
  const next = (name, output = 0) => ((wf.connections[name] && wf.connections[name].main[output]) || []).map((c) => c.node);
  for (const a of ['restart', 'rollback', 'scale', 'circuit_breaker']) assert.deepEqual(next('Execute: ' + a), ['Call executor?']);
  assert.deepEqual(next('Call executor?', 0), ['Executor: execute']);
  assert.deepEqual(next('Call executor?', 1), ['Sign complete request']);
  assert.deepEqual(next('Executor: execute'), ['Check executor result']);
  assert.deepEqual(next('Check executor result'), ['Sign complete request']);
  const http = node('Executor: execute');
  assert.equal(http.type, 'n8n-nodes-base.httpRequest');
  assert.equal(http.parameters.url, '={{ $json.request.url }}');
  assert.equal(http.parameters.options.timeout, '={{ $json.request.timeout_ms || 15000 }}');
  assert.notEqual(http.retryOnFail, true, 'a retry would reuse the nonce and could restart twice');
  assert.equal(http.onError, 'continueRegularOutput');
  // No Code node in 06 builds a command or reads a container name.
  for (const n of wf.nodes.filter((x) => x.type === 'n8n-nodes-base.code')) {
    assert.doesNotMatch(n.parameters.jsCode, /child_process|execSync|spawn\(|docker /);
  }
});
