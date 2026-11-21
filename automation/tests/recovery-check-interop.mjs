// BD-3 interop: the request built by workflow 07 ("Sign recovery check request")
// is sent over HTTP to the REAL backend route POST /api/machine/recovery-checks
// (backend/src/routes/machine.routes.ts: real HMAC middleware, validation and
// error mapping). Only the database is replaced: a fake automation client that
// records the record_recovery_check call. The answer is then read by workflow
// 07's "Recovery result" node.
// Needs the backend's dev dependencies (tsx, express). Run from automation/:
//   npx --prefix ../backend tsx tests/recovery-check-interop.mjs
import assert from 'node:assert/strict';
import express from '../../backend/node_modules/express/index.js';
import { createMachineRouter } from '../../backend/src/routes/machine.routes.ts';
import { createMemoryNonceStore } from '../../backend/src/middleware/machine-auth.ts';
import { runCodeNode } from './code-node-harness.mjs';

const SECRET = 'interop-test-secret-0123456789abcdefghijkl';
const INC = '22222222-2222-4222-8222-222222222222';
const RUN = '11111111-1111-4111-8111-111111111111';
const CHECK_ID = '77777777-7777-4777-8777-777777777777';

const rpcCalls = [];
let dbAnswer = { data: CHECK_ID, error: null };
const fakeClient = { rpc: async (fn, args) => { rpcCalls.push({ fn, args }); return dbAnswer; } };

const app = express();
app.use('/api/machine', createMachineRouter({
  signingSecret: SECRET,
  automation: { get: async () => fakeClient, invalidate: () => {} },
  nonceStore: createMemoryNonceStore(),
}));
const server = await new Promise((resolve) => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
const BASE = 'http://127.0.0.1:' + server.address().port;
const ENV = { MACHINE_SIGNING_SECRET: SECRET, BACKEND_BASE_URL: BASE };

// Output of "Evaluate health" -> input of "Sign recovery check request".
const evaluated = (verdict) => ({
  incident_id: INC, playbook_run_id: RUN, service_name: 'checkout-api', action_type: 'restart', simulated: true,
  verdict, reason: verdict === 'recovered' ? null : 'error_rate above threshold',
  checks: [{ attempt: 1, healthy: verdict === 'recovered', signals: [{ name: 'up', value: 1 }, { name: 'error_rate', value: 0.003 }] }],
});

// Like the n8n HTTP Request node (raw JSON body, full response, never error).
async function send(request) {
  const res = await fetch(request.url, { method: request.method, headers: { ...request.headers, 'content-type': 'application/json' }, body: request.body });
  const text = await res.text();
  let body; try { body = JSON.parse(text); } catch { body = text; }
  return { statusCode: res.status, body, headers: {} };
}

async function store(verdict) {
  const [signed] = await runCodeNode('07-recovery-check/sign-store.js', { items: [evaluated(verdict)], env: ENV });
  assert.equal(signed.skip_store, false);
  const response = await send(signed.request);
  const [result] = await runCodeNode('07-recovery-check/result.js', { items: [response], nodes: { 'Sign recovery check request': [signed] } });
  return { signed, response, result };
}

try {
  // 1. recovered -> healthy, stored, id returned.
  let r = await store('recovered');
  assert.equal(r.response.statusCode, 201, JSON.stringify(r.response.body));
  assert.deepEqual(r.response.body, { success: true, message: 'Recovery check recorded.', data: { recovery_check_id: CHECK_ID } });
  assert.equal(rpcCalls.length, 1);
  assert.equal(rpcCalls[0].fn, 'record_recovery_check');
  assert.deepEqual(rpcCalls[0].args, {
    p_incident_id: INC,
    p_playbook_run_id: RUN,
    p_status: 'healthy',
    p_check_type: 'prometheus',
    p_details: { verdict: 'recovered', checks: evaluated('recovered').checks, reason: null, simulated_remediation: true },
  });
  assert.equal(r.result.stored, true);
  assert.equal(r.result.recovery_check_id, CHECK_ID);
  assert.equal(r.result.soft_failure, null);
  assert.equal(r.result.status, 'recovered');

  // 2. every verdict maps to a status the route (and recovery_checks_status_check) accepts.
  for (const [verdict, dbStatus] of [['not_recovered', 'unhealthy'], ['unable_to_verify', 'failed']]) {
    r = await store(verdict);
    assert.equal(r.response.statusCode, 201, verdict);
    assert.equal(rpcCalls.at(-1).args.p_status, dbStatus);
    assert.equal(r.result.stored, true);
  }

  // 3. the same signed request twice -> 409 replay, recorded once.
  const [signed] = await runCodeNode('07-recovery-check/sign-store.js', { items: [evaluated('recovered')], env: ENV });
  const before = rpcCalls.length;
  assert.equal((await send(signed.request)).statusCode, 201);
  const replay = await send(signed.request);
  assert.equal(replay.statusCode, 409);
  assert.equal(rpcCalls.length, before + 1);

  // 4. unknown incident (DC404) -> 404 is a REAL failure now: not_found + soft_failure (no longer "not_implemented").
  dbAnswer = { data: null, error: { code: 'DC404', message: 'Incident not found.' } };
  r = await store('recovered');
  assert.equal(r.response.statusCode, 404);
  assert.equal(r.result.stored, false);
  assert.equal(r.result.store_error.kind, 'not_found');
  assert.equal(r.result.store_error.message, 'Incident not found.');
  assert.equal(r.result.soft_failure.kind, 'recovery_store_failed');

  // 5. run of another incident (DC422) -> 400 -> soft failure.
  dbAnswer = { data: null, error: { code: 'DC422', message: 'The playbook run does not belong to this incident.' } };
  r = await store('recovered');
  assert.equal(r.response.statusCode, 400);
  assert.equal(r.result.soft_failure.kind, 'recovery_store_failed');

  // 6. unexpected database error -> 500, generic message, soft failure without internals.
  const logged = console.error; console.error = () => {};
  dbAnswer = { data: null, error: { code: 'XX000', message: 'internal detail password=hunter2' } };
  r = await store('recovered');
  console.error = logged;
  assert.equal(r.response.statusCode, 500);
  assert.equal(r.result.store_error.kind, 'server_error');
  assert.doesNotMatch(JSON.stringify(r.result), /hunter2|internal detail/);

  // 7. a wrong secret in n8n -> 401 -> soft failure (auth).
  dbAnswer = { data: CHECK_ID, error: null };
  const [badSigned] = await runCodeNode('07-recovery-check/sign-store.js', { items: [evaluated('recovered')], env: { ...ENV, MACHINE_SIGNING_SECRET: 'another-secret-another-secret-another!!' } });
  const bad = await send(badSigned.request);
  assert.equal(bad.statusCode, 401);
  const [badResult] = await runCodeNode('07-recovery-check/result.js', { items: [bad], nodes: { 'Sign recovery check request': [badSigned] } });
  assert.equal(badResult.store_error.kind, 'auth');
  assert.equal(badResult.soft_failure.kind, 'recovery_store_failed');

  console.log('Recovery check interop: PASS (workflow 07 request accepted by the real backend route; responses handled by 07)');
} finally {
  server.close();
}
