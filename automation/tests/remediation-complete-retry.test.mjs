// N-1: retry-safe completion in workflow 06 ("Sign complete request" ->
// "Backend: complete run" -> "Check completion" -> "Retry completion?").
// The loop is simulated with the real Code node scripts; the HTTP node's output
// is given by each test. Run: cd automation && node --test tests/remediation-complete-retry.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { runCodeNode } from './code-node-harness.mjs';
import { buildAll, WF } from '../scripts/build-workflows.mjs';

const RUN = '11111111-1111-4111-8111-111111111111';
const INC = '22222222-2222-4222-8222-222222222222';
const SECRET = 'unit-test-only-secret-0123456789abcdefghij';
const ENV = { MACHINE_SIGNING_SECRET: SECRET, BACKEND_BASE_URL: 'http://backend.test:3000' };
const PATH = '/api/machine/playbook-runs/' + RUN + '/complete';

// Output of "Execute: restart" (simulate mode): the first input of "Sign complete request".
const executed = (outcome = 'success') => ({
  valid: true, execution_mode: 'simulate', playbook_run_id: RUN, incident_id: INC, requested_action: 'restart',
  request_payload: { service_name: 'checkout-api' }, n8n_execution_id: '1001', started: true, action_type: 'restart',
  outcome, result: { action: 'restart', executed: false, simulated: true, service_name: 'checkout-api' },
});

// HTTP Request node outputs (full response + never error + continue on error).
const ok = { statusCode: 200, body: { success: true, data: { run_id: RUN, status: 'success', manual: false } } };
const http = (status, message) => ({ statusCode: status, body: { success: false, message: message || 'HTTP ' + status } });
const timeout = { error: { message: 'timeout of 1500ms exceeded', code: 'ECONNABORTED' } };
const reset = { error: { message: 'socket hang up', code: 'ECONNRESET' } };

// Runs the loop like n8n does: sign, answer with responses[i], check; repeat while retry_complete.
async function runLoop(responses, { outcome = 'success', env = {} } = {}) {
  let input = executed(outcome);
  const sent = [];
  for (let i = 0; i < 10; i++) {
    const [signed] = await runCodeNode('06-remediation/sign-complete.js', { items: [input], env: { ...ENV, ...env } });
    sent.push(signed);
    const response = responses[i];
    assert.ok(response, 'the workflow made more attempts than the test answered (' + (i + 1) + ')');
    const [checked] = await runCodeNode('06-remediation/check-complete.js', { items: [response], nodes: { 'Sign complete request': [signed] }, env: { ...ENV, ...env } });
    if (!checked.retry_complete) return { final: checked, sent };
    input = checked;
  }
  throw new Error('retry loop did not end');
}

const verifies = (req) => {
  const ts = req.headers['X-DC-Timestamp'];
  const nonce = req.headers['X-DC-Nonce'];
  const expected = 'sha256=' + createHmac('sha256', SECRET).update([ts, nonce, 'POST', req.path, req.body].join('.'), 'utf8').digest('hex');
  return req.headers['X-DC-Signature'] === expected;
};

test('N-1: 503, 503, 200 -> completed on the third attempt, each attempt signed with a new nonce', async () => {
  const { final, sent } = await runLoop([http(503), http(503), ok]);
  assert.equal(sent.length, 3);
  assert.equal(final.completed, true);
  assert.equal(final.completion_confirmed_by, 'response');
  assert.equal(final.complete_attempts, 3);
  assert.equal(final.check_recovery, true);
  assert.equal(final.soft_failure, null);
  assert.equal(final.complete_error, null);
  const nonces = sent.map((s) => s.request.headers['X-DC-Nonce']);
  assert.equal(new Set(nonces).size, 3, 'every attempt must use a different nonce: ' + nonces.join(', '));
  for (const s of sent) {
    assert.equal(s.request.path, PATH);
    assert.ok(verifies(s.request), 'every attempt has a valid signature for its own nonce');
    assert.deepEqual(JSON.parse(s.request.body), { n8n_execution_id: '1001', status: 'success', result: executed().result }, 'same body on every attempt');
  }
  assert.deepEqual(sent.map((s) => s.complete_attempt), [1, 2, 3]);
  assert.deepEqual(final.complete_history.map((h) => h.http_status), [503, 503, 200]);
});

test('N-1: backoff is bounded and exponential (2 s, 4 s by default; configurable)', async () => {
  const [signed] = await runCodeNode('06-remediation/sign-complete.js', { items: [executed()], env: ENV });
  const [first] = await runCodeNode('06-remediation/check-complete.js', { items: [http(503)], nodes: { 'Sign complete request': [signed] }, env: ENV });
  assert.equal(first.retry_complete, true);
  assert.equal(first.wait_seconds, 2);
  const [signed2] = await runCodeNode('06-remediation/sign-complete.js', { items: [first], env: ENV });
  const [second] = await runCodeNode('06-remediation/check-complete.js', { items: [http(503)], nodes: { 'Sign complete request': [signed2] }, env: ENV });
  assert.equal(second.wait_seconds, 4);
  const [fast] = await runCodeNode('06-remediation/check-complete.js', { items: [http(503)], nodes: { 'Sign complete request': [signed] }, env: { ...ENV, COMPLETE_RETRY_BASE_SECONDS: '1' } });
  assert.equal(fast.wait_seconds, 1);
  const [capped] = await runCodeNode('06-remediation/check-complete.js', { items: [http(503)], nodes: { 'Sign complete request': [signed] }, env: { ...ENV, COMPLETE_RETRY_BASE_SECONDS: '9999' } });
  assert.equal(capped.wait_seconds, 30);
});

test('N-1: timeout on every attempt -> 3 attempts, final failure with a redacted soft_failure', async () => {
  const { final, sent } = await runLoop([timeout, timeout, timeout]);
  assert.equal(sent.length, 3);
  assert.equal(final.completed, false);
  assert.equal(final.check_recovery, false);
  assert.equal(final.complete_error.kind, 'timeout');
  assert.equal(final.complete_error.attempts, 3);
  assert.equal(final.soft_failure.kind, 'completion_failed');
  assert.match(final.soft_failure.message, /failed after 3 attempt\(s\): timeout/);
  assert.match(final.soft_failure.message, new RegExp(RUN));
  const text = JSON.stringify(final);
  assert.ok(!text.includes(SECRET), 'no secret in the output');
  assert.ok(!('request' in final), 'no signed request in the final output');
  assert.doesNotMatch(text, /X-DC-Signature|sha256=/);
});

test('N-1: connection error is retried', async () => {
  const { final, sent } = await runLoop([reset, ok]);
  assert.equal(sent.length, 2);
  assert.equal(final.completed, true);
  assert.equal(final.complete_history[0].kind, 'unavailable');
});

test('N-1: HTTP 500 is retried', async () => {
  const { final, sent } = await runLoop([http(500), ok]);
  assert.equal(sent.length, 2);
  assert.equal(final.completed, true);
});

for (const [status, message] of [[400, 'Status must be success or failed.'], [401, 'Invalid request signature.'], [403, 'The execution id does not match this run.'], [404, 'Playbook run not found.'], [429, 'Too many requests.']]) {
  test('N-1: HTTP ' + status + ' is not retried and is reported as the final failure', async () => {
    const { final, sent } = await runLoop([http(status, message)]);
    assert.equal(sent.length, 1, 'no retry for HTTP ' + status);
    assert.equal(final.completed, false);
    assert.equal(final.complete_error.http_status, status);
    assert.equal(final.complete_error.attempts, 1);
    assert.equal(final.soft_failure.kind, 'completion_failed');
  });
}

test('N-1: a first-attempt 409 (run not running) is a real failure, not a success', async () => {
  const { final, sent } = await runLoop([http(409, 'The run is success, not running.')]);
  assert.equal(sent.length, 1);
  assert.equal(final.completed, false, 'without an earlier ambiguous attempt the run was completed by someone else');
});

test('N-1: response lost after the database completed the run -> retry gets 409 with our status -> completed, not failed', async () => {
  const { final, sent } = await runLoop([timeout, http(409, 'The run is success, not running.')]);
  assert.equal(sent.length, 2);
  assert.equal(final.completed, true);
  assert.equal(final.completion_confirmed_by, 'run_state');
  assert.equal(final.check_recovery, true);
  assert.equal(final.soft_failure, null);
});

test('N-1: 409 with a DIFFERENT status after an ambiguous attempt is still a failure', async () => {
  // We reported "success", but the run is now "failed" (or cancelled): not ours.
  const { final } = await runLoop([timeout, http(409, 'The run is failed, not running.')]);
  assert.equal(final.completed, false);
  const { final: cancelled } = await runLoop([http(503), http(409, 'The run is cancelled, not running.')]);
  assert.equal(cancelled.completed, false);
  assert.equal(cancelled.soft_failure.kind, 'completion_failed');
});

test('N-1: a failed remediation (outcome failed) is completed as failed; recovery is not checked', async () => {
  const { final, sent } = await runLoop([http(502), ok], { outcome: 'failed' });
  assert.equal(JSON.parse(sent[1].request.body).status, 'failed');
  assert.equal(final.completed, true);
  assert.equal(final.check_recovery, false);
  assert.equal(final.soft_failure, null);
});

test('N-1: a successful first attempt is not repeated', async () => {
  const { final, sent } = await runLoop([ok]);
  assert.equal(sent.length, 1);
  assert.equal(final.completed, true);
  assert.equal(final.retry_complete, false);
  assert.equal(final.complete_attempts, 1);
});

test('N-1: BACKEND_TIMEOUT_MS sets the timeout of signed requests (default 15 s, bounded)', async () => {
  const t = async (v) => (await runCodeNode('06-remediation/sign-complete.js', { items: [executed()], env: { ...ENV, BACKEND_TIMEOUT_MS: v } }))[0].request.timeout_ms;
  assert.equal(await t(undefined), 15000);
  assert.equal(await t('1500'), 1500);
  assert.equal(await t('10'), 1000);
  assert.equal(await t('999999'), 60000);
  assert.equal(await t('abc'), 15000);
});

test('N-1: workflow 06 wiring: complete -> check -> retry? (true: wait -> sign again; false: recovery check)', () => {
  const wf = buildAll().find((w) => w.meta.id === WF.remediation.id).json;
  const out = (name) => wf.connections[name].main.map((o) => o.map((l) => l.node));
  assert.deepEqual(out('Backend: complete run'), [['Check completion']]);
  assert.deepEqual(out('Check completion'), [['Retry completion?']]);
  assert.deepEqual(out('Retry completion?'), [['Wait before completion retry'], ['Check recovery?']]);
  assert.deepEqual(out('Wait before completion retry'), [['Sign complete request']]);
  const httpNode = wf.nodes.find((n) => n.name === 'Backend: complete run');
  assert.ok(!httpNode.retryOnFail, 'the HTTP node itself never re-sends a signed request');
  assert.equal(httpNode.parameters.options.timeout, '={{ $json.request.timeout_ms || 15000 }}');
  const wait = wf.nodes.find((n) => n.name === 'Wait before completion retry');
  assert.equal(wait.parameters.amount, '={{ $json.wait_seconds }}');
});
