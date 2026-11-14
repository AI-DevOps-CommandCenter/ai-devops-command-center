// I-3: workflow 06 takes the remediation context (service_name) from the run's
// request_payload returned by the DATABASE (start_playbook_run), never from the
// webhook body. Run: cd automation && node --test tests/remediation-db-payload.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { runCodeNode } from './code-node-harness.mjs';
import { buildAll, WF } from '../scripts/build-workflows.mjs';

const RUN = '11111111-1111-4111-8111-111111111111';
const INC = '22222222-2222-4222-8222-222222222222';
const SECRET = 'unit-test-only-secret-0123456789abcdefghij';

// Output of "Sign start request": the webhook context (verify-request) + the signed request.
const signedStart = (webhookPayload, requested = 'restart') => ({
  valid: true, execution_mode: 'simulate', playbook_run_id: RUN, incident_id: INC,
  requested_action: requested, request_payload: webhookPayload, n8n_execution_id: '1001', request: {},
});
// Backend answer of POST /api/machine/playbook-runs/:id/start (shape of start_playbook_run).
const dbStart = (fields = {}) => ({
  statusCode: 200,
  body: { success: true, data: { run_id: RUN, status: 'running', automation_run_id: '44444444-4444-4444-8444-444444444444', incident_id: INC, action_type: 'restart', request_payload: { service_name: 'db-svc' }, ...fields } },
});
const checkStart = (webhookPayload, response, requested) => runCodeNode('06-remediation/check-start.js', {
  items: [response], nodes: { 'Sign start request': [signedStart(webhookPayload, requested)] },
}).then((r) => r[0]);
// "Check completion" after "Sign complete request" (which keeps the check-start context).
const checkComplete = (startOut, outcome, result) => runCodeNode('06-remediation/check-complete.js', {
  items: [{ statusCode: 200, body: { success: true } }],
  nodes: { 'Sign complete request': [{ ...startOut, outcome, result, request: {} }] },
}).then((r) => r[0]);

test('I-3: the database request_payload is the source of truth for service_name', async () => {
  const o = await checkStart({ service_name: 'db-svc' }, dbStart());
  assert.equal(o.started, true);
  assert.equal(o.http_status, 202);
  assert.deepEqual(o.request_payload, { service_name: 'db-svc' });
  const done = await checkComplete(o, 'success', { action: 'restart', executed: false, simulated: true, service_name: 'db-svc' });
  assert.equal(done.service_name, 'db-svc');
  assert.equal(done.check_recovery, true);
  assert.equal(done.simulated, true);
});

test('I-3: a conflicting webhook service_name cannot override the database value', async () => {
  const o = await checkStart({ service_name: 'webhook-svc', extra: 'x' }, dbStart());
  assert.equal(o.started, true);
  assert.deepEqual(o.request_payload, { service_name: 'db-svc' }, 'the webhook copy is replaced');
  assert.ok(!JSON.stringify(o).includes('webhook-svc'));
  // Even a result carrying another service name does not win over the database copy.
  const done = await checkComplete(o, 'success', { action: 'restart', simulated: true, service_name: 'webhook-svc' });
  assert.equal(done.service_name, 'db-svc');
});

test('I-3: missing or invalid service_name in the database run -> nothing executed, run completed as failed', async () => {
  const cases = [
    ['payload without service_name', { request_payload: {} }],
    ['null payload', { request_payload: null }],
    ['no payload field', { request_payload: undefined }],
    ['array payload', { request_payload: ['db-svc'] }],
    ['invalid characters', { request_payload: { service_name: 'svc"} or 1=1' } }],
    ['empty string', { request_payload: { service_name: '' } }],
  ];
  for (const [name, fields] of cases) {
    // The webhook offers a service name: it must NOT be used to fill the gap.
    const o = await checkStart({ service_name: 'webhook-svc' }, dbStart(fields));
    assert.equal(o.started, false, name);
    assert.equal(o.started_but_rejected, true, name + ': a started run must be completed (as failed)');
    assert.equal(o.http_status, 409, name);
    assert.match(o.rejection, /request_payload/, name);
    assert.equal(o.response.accepted, false, name);
    assert.ok(!JSON.stringify(o).includes('webhook-svc'), name + ': webhook value not used');
    // The workflow then goes "Unsupported or rejected action" -> complete as failed.
    const [failed] = await runCodeNode('06-remediation/unsupported-action.js', { items: [o] });
    assert.equal(failed.outcome, 'failed', name);
    assert.equal(failed.result.executed, false, name);
    const done = await checkComplete(o, failed.outcome, failed.result);
    assert.equal(done.check_recovery, false, name + ': no recovery check');
    assert.equal(done.service_name, null, name + ': no service is guessed');
  }
});

test('I-3: approval checks unchanged: a refused start never executes and is not completed', async () => {
  for (const [status, message] of [[409, 'The run is pending, not approved.'], [409, 'The run has no approved approval.'], [404, 'Playbook run not found.'], [401, 'Invalid request signature.']]) {
    const o = await checkStart({ service_name: 'webhook-svc' }, { statusCode: status, body: { success: false, message } });
    assert.equal(o.started, false);
    assert.ok(!o.started_but_rejected, 'not started -> nothing to complete');
    assert.equal(o.http_status, status === 401 ? 502 : status);
    assert.deepEqual(o.request_payload, {}, 'webhook payload is dropped');
  }
  // Database says the run is not running.
  const notRunning = await checkStart({ service_name: 'db-svc' }, dbStart({ status: 'approved' }));
  assert.equal(notRunning.started, false);
  assert.match(notRunning.rejection, /run status is approved/);
});

test('I-3: action validation unchanged: the database action must match the requested action', async () => {
  const o = await checkStart({ service_name: 'db-svc' }, dbStart({ action_type: 'rollback' }), 'restart');
  assert.equal(o.started, false);
  assert.equal(o.started_but_rejected, true);
  assert.equal(o.action_type, 'rollback', 'the database action is reported, not the webhook action');
  assert.match(o.rejection, /action_type does not match/);
  const otherIncident = await checkStart({ service_name: 'db-svc' }, dbStart({ incident_id: '99999999-9999-4999-8999-999999999999' }));
  assert.match(otherIncident.rejection, /incident_id does not match/);

  // The signed webhook still accepts only the four actions and the four fields.
  const sign = (raw, ts = Math.floor(Date.now() / 1000), nonce = 'nonce-' + Math.random().toString(36).slice(2, 14) + 'abcdef') => ({
    'x-dc-timestamp': String(ts), 'x-dc-nonce': nonce,
    'x-dc-signature': 'sha256=' + createHmac('sha256', SECRET).update([ts, nonce, 'POST', '/webhook/remediation', raw].join('.'), 'utf8').digest('hex'),
  });
  const verify = (body) => runCodeNode('06-remediation/verify-request.js', {
    items: [{ headers: sign(body), body: JSON.parse(body) }],
    binary: { data: { data: Buffer.from(body).toString('base64'), mimeType: 'application/json' } },
    env: { MACHINE_SIGNING_SECRET: SECRET, REMEDIATION_EXECUTION_MODE: 'simulate' }, staticData: {},
  }).then((r) => r[0]);
  assert.equal((await verify(JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart', request_payload: { service_name: 'x' } }))).valid, true);
  assert.equal((await verify(JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'delete_db' }))).http_status, 400);
  assert.equal((await verify(JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart', command: 'rm -rf /' }))).http_status, 400);
});

test('I-3: workflow 06 wiring unchanged and the generated JSON contains the fix', () => {
  const wf = buildAll().find((w) => w.meta.id === WF.remediation.id).json;
  const link = (from, out) => wf.connections[from].main[out].map((l) => l.node);
  assert.deepEqual(link('Run started?', 0), ['Respond 202']);
  assert.deepEqual(link('Run started?', 1), ['Respond refused']);
  assert.deepEqual(link('Respond refused', 0), ['Started but mismatched?']);
  assert.deepEqual(link('Started but mismatched?', 0), ['Unsupported or rejected action']);
  assert.deepEqual(link('Unsupported or rejected action', 0), ['Sign complete request']);
  assert.deepEqual(link('Execution available?', 1), ['Execution blocked response'], 'disabled mode still refuses before start');
  const code = wf.nodes.find((n) => n.name === 'Check start result').parameters.jsCode;
  assert.match(code, /request_payload\.service_name is missing or invalid in the database run/);
});
