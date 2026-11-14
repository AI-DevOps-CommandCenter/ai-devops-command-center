// N-2: soft failures (completion failed after retries, start unconfirmed, AI
// unavailable, result not stored) reach workflow 09 as a short, redacted
// notification; expected states (BD-2 not implemented, run not approved,
// success) stay silent. Run: cd automation && node --test tests/soft-failure.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runCodeNode } from './code-node-harness.mjs';
import { buildAll, WF } from '../scripts/build-workflows.mjs';

const RUN = '11111111-1111-4111-8111-111111111111';
const INC = '22222222-2222-4222-8222-222222222222';
const SECRET = 'unit-test-only-secret-0123456789abcdefghij';
const HOOK = 'https://hooks.example.test/notify/T000/B000/n2-unit-test-only-token';

// Output of "Sign start request" (with the signed request that must never leak).
const signedStart = { valid: true, execution_mode: 'simulate', playbook_run_id: RUN, incident_id: INC, requested_action: 'restart', request_payload: {}, n8n_execution_id: '1001', request: { headers: { 'X-DC-Signature': 'sha256=' + 'a'.repeat(64), 'X-DC-Nonce': 'nonce-must-not-leak-123' }, body: '{"n8n_execution_id":"1001"}' } };
const checkStart = (response) => runCodeNode('06-remediation/check-start.js', { items: [response], nodes: { 'Sign start request': [signedStart] } }).then((r) => r[0]);
const report = (items, workflow = { id: WF.remediation.id, name: WF.remediation.name }) => runCodeNode('09-error-handler/report-soft-failure.js', { items, workflow, executionId: '777' });
const summarize = (item, env = { ERROR_NOTIFY_WEBHOOK_URL: HOOK }) => runCodeNode('09-error-handler/summarize-error.js', { items: [item], env }).then((r) => r[0]);

// ---------- detection ----------
test('N-2: start timeout / connection error / 5xx -> start_unconfirmed', async () => {
  for (const response of [{ error: { message: 'timeout of 15000ms exceeded', code: 'ECONNABORTED' } }, { error: { message: 'connect ECONNREFUSED 127.0.0.1:3000' } }, { statusCode: 500, body: { success: false, message: 'Failed to start playbook run.' } }]) {
    const o = await checkStart(response);
    assert.equal(o.started, false);
    assert.equal(o.http_status, 502);
    assert.equal(o.soft_failure.kind, 'start_unconfirmed', JSON.stringify(response));
    assert.match(o.soft_failure.message, /may have started the run/);
  }
});

test('N-2: start rejected by a misconfiguration (401 signature, 503 machine endpoints off) -> start_failed', async () => {
  for (const status of [401, 503]) {
    const o = await checkStart({ statusCode: status, body: { success: false, message: 'x' } });
    assert.equal(o.soft_failure.kind, 'start_failed', 'HTTP ' + status);
  }
});

test('N-2: expected start refusals (409 not approved, 404, 400) are silent', async () => {
  for (const status of [409, 404, 400]) {
    const o = await checkStart({ statusCode: status, body: { success: false, message: 'The run is pending, not approved.' } });
    assert.equal(o.started, false);
    assert.equal(o.soft_failure, null, 'HTTP ' + status + ' must not notify');
  }
});

test('N-2: a started run has no soft failure', async () => {
  const o = await checkStart({ statusCode: 200, body: { success: true, data: { status: 'running', incident_id: INC, action_type: 'restart', request_payload: { service_name: 'svc' } } } });
  assert.equal(o.started, true);
  assert.equal(o.soft_failure, undefined);
});

const storeSigned = { incident_id: INC, investigation_id: '66666666-6666-4666-8666-666666666666', service_name: 'svc', valid: true, can_store: true, rca: { summary: 's' }, request: { headers: { 'X-DC-Nonce': 'nonce-must-not-leak-123' } } };
const stored = (response) => runCodeNode('05-root-cause/result-stored.js', { items: [response], nodes: { 'Sign store request': [storeSigned] } }).then((r) => r[0]);

test('N-2: AI analysis store error (5xx, 401, timeout) -> rca_store_failed', async () => {
  for (const response of [{ statusCode: 500, body: { message: 'Failed.' } }, { statusCode: 401, body: { message: 'Invalid request signature.' } }, { error: { message: 'ETIMEDOUT' } }]) {
    const o = await stored(response);
    assert.equal(o.stored, false);
    assert.equal(o.soft_failure.kind, 'rca_store_failed', JSON.stringify(response));
    assert.ok(!('request' in o));
  }
});

test('N-2: expected not_implemented (404: BD-2 route missing) does not produce a misleading alert', async () => {
  const o = await stored({ statusCode: 404, body: { success: false, message: 'Route not found.' } });
  assert.equal(o.store_error.kind, 'not_implemented');
  assert.equal(o.soft_failure, null);
  const okRes = await stored({ statusCode: 201, body: { success: true, data: { analysis_id: 'a1' } } });
  assert.equal(okRes.stored, true);
  assert.equal(okRes.soft_failure, null);
});

test('N-2: AI unavailable -> ai_unavailable; a valid analysis that is only BLOCKED (BD-1/BD-2) is silent', async () => {
  const unavailable = { incident_id: null, service_name: 'checkout-api', valid: false, can_store: false, status: 'ai_unavailable', error: { kind: 'rate_limited', http_status: 429, message: 'Rate limit reached' } };
  const [o] = await runCodeNode('05-root-cause/result-not-stored.js', { items: [unavailable] });
  assert.equal(o.soft_failure.kind, 'ai_unavailable');
  assert.match(o.soft_failure.message, /checkout-api: rate_limited HTTP 429 - Rate limit reached/);
  const blocked = { incident_id: null, valid: true, can_store: false, status: 'analysis_ready', store_blocker: 'No incident_id (BD-1).' };
  assert.equal((await runCodeNode('05-root-cause/result-not-stored.js', { items: [blocked] }))[0].soft_failure, null);
  const invalid = { valid: false, can_store: false, status: 'invalid_ai_response', error: { kind: 'schema_validation' } };
  assert.equal((await runCodeNode('05-root-cause/result-not-stored.js', { items: [invalid] }))[0].soft_failure, null);
});

test('N-2: workflow 01 intake result passes the soft failure returned by 05', async () => {
  const created = [{ alert_name: 'A', service_name: 'svc', incident_id: null, incident_created: false }, { alert_name: 'B', service_name: 'svc2', incident_id: null, incident_created: false }];
  const out = await runCodeNode('01-alert-intake/intake-result.js', {
    items: [{ status: 'ai_unavailable', soft_failure: { kind: 'ai_unavailable', node: 'Groq: RCA', message: 'm' } }, { status: 'analysis_ready', stored: false }],
    nodes: { 'Create incident (backend) – BLOCKED': created },
  });
  assert.equal(out[0].soft_failure.kind, 'ai_unavailable');
  assert.equal(out[1].soft_failure, null);
});

test('N-2: soft-failure messages keep the backend message, without a doubled period', async () => {
  const start = await checkStart({ error: { message: 'timeout of 1500ms exceeded', code: 'ECONNABORTED' } });
  assert.match(start.soft_failure.message, /failed: timeout - Request timed out\. The backend may have started/);
  const [signedComplete] = await runCodeNode('06-remediation/sign-complete.js', { items: [{ playbook_run_id: RUN, incident_id: INC, n8n_execution_id: '1001', outcome: 'success', result: {} }], env: { MACHINE_SIGNING_SECRET: SECRET, BACKEND_BASE_URL: 'http://b.test' } });
  const [complete] = await runCodeNode('06-remediation/check-complete.js', { items: [{ statusCode: 400, body: { message: 'Status must be success or failed.' } }], nodes: { 'Sign complete request': [signedComplete] } });
  assert.match(complete.soft_failure.message, /client_error HTTP 400 - Status must be success or failed\. The run may still be "running"/);
  const store = await stored({ statusCode: 500, body: { message: 'Failed to record.' } });
  assert.match(store.soft_failure.message, /server_error HTTP 500 - Failed to record\.$/);
  for (const m of [start.soft_failure.message, complete.soft_failure.message, store.soft_failure.message]) assert.doesNotMatch(m, /\.\./, m);
});

// ---------- reporting ----------
test('N-2: report groups items: three alerts with the AI down -> ONE notification', async () => {
  const f = (svc) => ({ soft_failure: { kind: 'ai_unavailable', node: 'Groq: RCA', message: 'The AI (Groq) could not be used for ' + svc + ': timeout.' } });
  const out = await report([f('a'), f('b'), f('a'), { soft_failure: null }, {}], { id: WF.intake.id, name: WF.intake.name });
  assert.equal(out.length, 1);
  assert.equal(out[0].soft_failure.count, 3);
  assert.equal(out[0].workflow.name, '01 - Alert Intake');
  assert.equal(out[0].execution.id, '777');
  assert.equal(out[0].execution.mode, 'soft_failure');
  assert.match(out[0].execution.error.message, /^soft failure ai_unavailable \(3 items\): /);
  // Identical messages are listed once.
  assert.equal(out[0].execution.error.message.split('could not be used for a').length - 1, 1);
});

test('N-2: no soft failure (successful execution) -> no notification item', async () => {
  assert.deepEqual(await report([{ soft_failure: null, completed: true }, { status: 'recovered' }]), []);
});

test('N-2: completion failure -> 09 notification text, redacted, no secrets or request data', async () => {
  const final = { playbook_run_id: RUN, completed: false, soft_failure: { kind: 'completion_failed', node: 'Backend: complete run', message: 'Completing playbook run ' + RUN + ' failed after 3 attempt(s): server_error HTTP 503 - token=ghp_abcdefghijklmnopqrstuvwxyz123456 Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abcdefghij ' + HOOK } };
  const [item] = await report([final]);
  const [again] = await report([final]);
  assert.deepEqual(item, again, 'deterministic');
  const o = await summarize(item);
  const text = JSON.stringify(o);
  for (const leaked of ['ghp_abcdef', 'eyJhbGci', 'n2-unit-test-only-token', SECRET, 'nonce-must-not-leak', 'sha256=']) {
    assert.ok(!text.includes(leaked), 'leaked: ' + leaked + ' in ' + text);
  }
  assert.equal(o.notify, true);
  assert.equal(o.workflow, '06 - Remediation');
  assert.equal(o.failed_node, 'Backend: complete run');
  const payload = JSON.parse(o.body);
  assert.match(payload.text, /^\[n8n\] 06 - Remediation failed at "Backend: complete run": soft failure completion_failed: Completing playbook run 11111111-1111-4111-8111-111111111111/);
  assert.equal(payload.text, payload.content);
  assert.ok(o.message.length <= 300);
});

test('N-2: the soft failure of an unconfirmed start never carries the signed request', async () => {
  const o = await checkStart({ error: { message: 'timeout', code: 'ECONNABORTED' } });
  const [item] = await report([o]);
  const text = JSON.stringify(item);
  assert.ok(!text.includes('nonce-must-not-leak') && !text.includes('sha256='), text);
  assert.match(item.execution.error.message, /start_unconfirmed/);
});

// ---------- wiring ----------
const wf = (meta) => buildAll().find((w) => w.meta.id === meta.id).json;
const out = (w, name) => w.connections[name].main.map((o) => o.map((l) => l.node));

test('N-2: 06 sends start/completion/recovery soft failures to 09; 01 sends the ones returned by 05', () => {
  const w06 = wf(WF.remediation);
  assert.deepEqual(out(w06, 'Started but mismatched?')[1], ['Soft failure?']);
  assert.deepEqual(out(w06, 'Done (no recovery check)'), [['Soft failure?']]);
  assert.deepEqual(out(w06, 'Run 07 Recovery Check'), [['Soft failure?']]);
  for (const w of [w06, wf(WF.intake)]) {
    assert.deepEqual(out(w, 'Soft failure?'), [['Report soft failure']]);
    assert.deepEqual(out(w, 'Report soft failure'), [['Notify error handler (09)']]);
    const notify = w.nodes.find((n) => n.name === 'Notify error handler (09)');
    assert.equal(notify.parameters.workflowId.value, WF.errors.id);
    assert.equal(notify.parameters.mode, 'each', 'one 09 run per kind of failure');
    assert.equal(notify.onError, 'continueRegularOutput', 'a failing notification never breaks the workflow');
  }
  assert.deepEqual(out(wf(WF.intake), 'Intake result'), [['Soft failure?']]);
});

test('N-2: sub-workflows 05 and 07 do not notify (their result is their last node output)', () => {
  for (const meta of [WF.rca, WF.recovery]) {
    const executes = wf(meta).nodes.filter((n) => n.type === 'n8n-nodes-base.executeWorkflow').map((n) => n.parameters.workflowId.value);
    assert.ok(!executes.includes(WF.errors.id), meta.name + ' must not call 09 itself');
    assert.ok(!wf(meta).nodes.some((n) => n.name === 'Report soft failure'), meta.name);
  }
});

test('N-2: 09 has a sub-workflow entry point that feeds the same redacting summary node', () => {
  const w09 = wf(WF.errors);
  const trigger = w09.nodes.find((n) => n.name === 'When called with a soft failure');
  assert.equal(trigger.type, 'n8n-nodes-base.executeWorkflowTrigger');
  assert.deepEqual(out(w09, 'When called with a soft failure'), [['Summarize error']]);
  assert.deepEqual(out(w09, 'On workflow error'), [['Summarize error']]);
});
