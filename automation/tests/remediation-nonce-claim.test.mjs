// KI-1 / D-N8N-6: workflow 06 claims the webhook nonce in the database before
// the run is started. Run: cd automation && node --test tests/remediation-nonce-claim.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { runCodeNode } from './code-node-harness.mjs';
import { buildAll, WF } from '../scripts/build-workflows.mjs';

const RUN = '11111111-1111-4111-8111-111111111111';
const INC = '22222222-2222-4222-8222-222222222222';
const SECRET = 'unit-test-only-secret-0123456789abcdefghij';
const NONCE = 'webhookNonce-0123456789';

const verified = { valid: true, execution_mode: 'simulate', execution_available: true, playbook_run_id: RUN, incident_id: INC,
  requested_action: 'restart', request_payload: {}, webhook_nonce: NONCE, webhook_signed_at: 1763467200 };

test('verify passes the webhook nonce and timestamp on for the database claim', async () => {
  const raw = JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart', request_payload: {} });
  const ts = Math.floor(Date.now() / 1000);
  const headers = {
    'x-dc-timestamp': String(ts), 'x-dc-nonce': NONCE,
    'x-dc-signature': 'sha256=' + createHmac('sha256', SECRET).update([ts, NONCE, 'POST', '/webhook/remediation', raw].join('.'), 'utf8').digest('hex'),
  };
  const [o] = await runCodeNode('06-remediation/verify-request.js', {
    items: [{ headers, body: JSON.parse(raw) }],
    binary: { data: { data: Buffer.from(raw).toString('base64'), mimeType: 'application/json' } },
    env: { MACHINE_SIGNING_SECRET: SECRET, REMEDIATION_EXECUTION_MODE: 'simulate' }, staticData: {},
  });
  assert.equal(o.valid, true);
  assert.equal(o.webhook_nonce, NONCE);
  assert.equal(o.webhook_signed_at, ts);
});

test('sign nonce claim: signed POST /api/machine/remediation-nonces with only nonce + signed_at', async () => {
  const [o] = await runCodeNode('06-remediation/sign-claim-nonce.js', {
    items: [verified],
    env: { MACHINE_SIGNING_SECRET: SECRET, BACKEND_BASE_URL: 'http://backend.test:3000' },
  });
  assert.equal(o.request.method, 'POST');
  assert.equal(o.request.url, 'http://backend.test:3000/api/machine/remediation-nonces');
  assert.deepEqual(JSON.parse(o.request.body), { nonce: NONCE, signed_at: 1763467200 });
  assert.match(o.request.headers['X-DC-Signature'] || o.request.headers['x-dc-signature'], /^sha256=[0-9a-f]{64}$/);
  assert.notEqual(o.request.headers['X-DC-Nonce'] || o.request.headers['x-dc-nonce'], NONCE, 'n8n signs its own call with a new nonce');
});

const check = (response) => runCodeNode('06-remediation/check-nonce-claim.js', {
  items: [response], nodes: { 'Sign nonce claim': [{ ...verified, request: {} }] },
}).then((r) => r[0]);

test('check nonce claim: 200 continues, 409 is a replay, 401 window, anything else fails closed', async () => {
  const ok = await check({ statusCode: 200, body: { success: true, message: 'Nonce accepted.' } });
  assert.equal(ok.nonce_claimed, true);
  assert.equal(ok.playbook_run_id, RUN);
  assert.equal(ok.request, undefined, 'the signed request is not carried on');

  const replay = await check({ statusCode: 409, body: { success: false, message: 'Replayed request (nonce already used).' } });
  assert.equal(replay.nonce_claimed, false);
  assert.equal(replay.http_status, 409);
  assert.match(replay.response.message, /Replayed request/);

  assert.equal((await check({ statusCode: 401, body: { success: false } })).http_status, 401);

  for (const failure of [
    { statusCode: 500, body: { success: false } },
    { statusCode: 503, body: { success: false, message: 'Machine endpoints are not configured.' } },
    { statusCode: 404, body: { success: false, message: 'Route not found.' } },
    { error: { code: 'ECONNREFUSED', message: 'connect ECONNREFUSED' } },
  ]) {
    const o = await check(failure);
    assert.equal(o.nonce_claimed, false, JSON.stringify(failure));
    assert.equal(o.http_status, 503, JSON.stringify(failure));
  }
});

test('06 wiring: the nonce is claimed after "Execution available?" and before the start', () => {
  const wf = buildAll().find((w) => w.meta.id === WF.remediation.id).json;
  const link = (from, out = 0) => wf.connections[from].main[out].map((l) => l.node);
  assert.deepEqual(link('Execution available?', 0), ['Sign nonce claim']);
  assert.deepEqual(link('Sign nonce claim'), ['Backend: claim webhook nonce']);
  assert.deepEqual(link('Backend: claim webhook nonce'), ['Check nonce claim']);
  assert.deepEqual(link('Check nonce claim'), ['Nonce claimed?']);
  assert.deepEqual(link('Nonce claimed?', 0), ['Sign start request']);
  assert.deepEqual(link('Nonce claimed?', 1), ['Respond replay or unverified']);
  assert.equal(wf.connections['Respond replay or unverified'], undefined, 'nothing runs after a refused claim');
});
