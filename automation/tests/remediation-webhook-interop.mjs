// BD-5 interop: a remediation webhook request signed by the backend's REAL
// buildSignedHeaders() (backend/src/middleware/machine-auth.ts) is checked by
// workflow 06's REAL "Verify signature and payload" Code node
// (src/nodes/06-remediation/verify-request.js, run through the code-node harness).
// The test only builds inputs: it never re-implements the signing logic.
//
// "disabled -> 503" is decided by n8n IF/Set nodes, not by a Code node, so the
// harness cannot run it. That case runs the real verifier (execution_mode) and
// then follows the routing in the generated workflows/06-remediation.json.
//
// Needs the backend's dev dependencies (tsx). Run from automation/:
//   npx --prefix ../backend tsx tests/remediation-webhook-interop.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { buildSignedHeaders } from '../../backend/src/middleware/machine-auth.ts';
import { runCodeNode } from './code-node-harness.mjs';

const VERIFY = '06-remediation/verify-request.js';
// Test-only secret (never a real one).
const SECRET = 'bd5-interop-test-only-secret-0123456789abcdef';
const SIGNED_PATH = '/webhook/remediation';
const ENV = { MACHINE_SIGNING_SECRET: SECRET, REMEDIATION_EXECUTION_MODE: 'simulate' };

// Realistic body (contract B.3): UUIDs, an allowed action_type and the payload
// the backend stores for the run.
const BODY = {
  playbook_run_id: '3f6c2a1e-8b4d-4c7a-9e21-5d0b7f3a9c41',
  incident_id: 'a7d94e02-1c3b-4f58-8a6e-2b9c0d4e7f13',
  action_type: 'restart',
  request_payload: { service_name: 'checkout-api' },
};

// A fresh nonce in the format n8n accepts (what the backend is expected to send).
const newNonce = () => randomBytes(24).toString('base64url');

// The backend side: serialize ONCE, sign that exact string with the real
// buildSignedHeaders(), and send the same string.
function backendSign(body, { path = SIGNED_PATH, nonce = newNonce(), now, secret = SECRET } = {}) {
  const raw = typeof body === 'string' ? body : JSON.stringify(body);
  const headers = buildSignedHeaders(secret, { method: 'POST', path, body: raw, nonce, now });
  return { raw, headers };
}

// The n8n side: what the Webhook node (Raw Body ON) hands to the Code node:
// parsed JSON in json.body, headers in json.headers, the exact bytes in binary.data.
async function n8nVerify({ raw, headers }, { env = ENV, staticData = {} } = {}) {
  const [out] = await runCodeNode(VERIFY, {
    items: [{ headers: { ...headers, 'content-type': 'application/json' }, body: JSON.parse(raw) }],
    binary: { data: { data: Buffer.from(raw, 'utf8').toString('base64'), mimeType: 'application/json' } },
    env,
    staticData,
  });
  return out;
}

test('valid request signed by the backend is accepted by workflow 06', async () => {
  const req = backendSign(BODY);
  // The exact string that was signed is the string handed to the verifier.
  assert.equal(Buffer.from(Buffer.from(req.raw, 'utf8').toString('base64'), 'base64').toString('utf8'), req.raw);
  const out = await n8nVerify(req);
  assert.equal(out.valid, true, JSON.stringify(out.response));
  assert.equal(out.playbook_run_id, BODY.playbook_run_id);
  assert.equal(out.incident_id, BODY.incident_id);
  assert.equal(out.requested_action, 'restart');
  assert.deepEqual(out.request_payload, BODY.request_payload);
  assert.equal(out.execution_mode, 'simulate');
});

test('signing a different string than the one sent -> 401', async () => {
  const req = backendSign(BODY);
  // Same JSON value, different bytes (re-serialized with spaces).
  const resent = { raw: JSON.stringify(BODY, null, 1), headers: req.headers };
  const out = await n8nVerify(resent);
  assert.equal(out.valid, false);
  assert.equal(out.http_status, 401);
});

test('wrong signed path -> 401', async () => {
  const out = await n8nVerify(backendSign(BODY, { path: '/webhook-test/remediation' }));
  assert.equal(out.valid, false);
  assert.equal(out.http_status, 401);
  assert.match(out.response.message, /Invalid request signature/);
});

test('any signature header missing -> 401 (each header checked separately)', async () => {
  const req = backendSign(BODY);
  // buildSignedHeaders() returns lower-case names; n8n also hands them over lower-case.
  for (const name of ['x-dc-timestamp', 'x-dc-nonce', 'x-dc-signature']) {
    const headers = { ...req.headers };
    assert.ok(name in headers, 'buildSignedHeaders() no longer returns ' + name);
    delete headers[name];
    const out = await n8nVerify({ raw: req.raw, headers });
    assert.equal(out.valid, false, name);
    assert.equal(out.http_status, 401, name);
    assert.match(out.response.message, /Signed request headers are required/, name);
  }
  const none = await n8nVerify({ raw: req.raw, headers: {} });
  assert.equal(none.http_status, 401);
});

test('signed by the backend with a different secret -> 401', async () => {
  const out = await n8nVerify(backendSign(BODY, { secret: 'another-backend-secret-0123456789abcdefgh' }));
  assert.equal(out.valid, false);
  assert.equal(out.http_status, 401);
  assert.match(out.response.message, /Invalid request signature/);
});

test('forged signature (one hex digit changed, well-formed) -> 401', async () => {
  const req = backendSign(BODY);
  const sig = req.headers['x-dc-signature'];
  const last = sig.slice(-1);
  const forged = sig.slice(0, -1) + (last === '0' ? '1' : '0');
  const out = await n8nVerify({ raw: req.raw, headers: { ...req.headers, 'x-dc-signature': forged } });
  assert.equal(out.valid, false);
  assert.equal(out.http_status, 401);
  assert.match(out.response.message, /Invalid request signature/);
});

test('expired timestamp (10 minutes old) -> 401', async () => {
  const out = await n8nVerify(backendSign(BODY, { now: new Date(Date.now() - 10 * 60 * 1000) }));
  assert.equal(out.valid, false);
  assert.equal(out.http_status, 401);
  assert.match(out.response.message, /outside the 5 minute window/);
});

test('invalid nonce format -> 401 (buildSignedHeaders does not check it)', async () => {
  for (const nonce of ['short', 'has+plus/slash=padding0123456789', 'x'.repeat(201)]) {
    const out = await n8nVerify(backendSign(BODY, { nonce }));
    assert.equal(out.valid, false, nonce);
    assert.equal(out.http_status, 401, nonce);
    assert.match(out.response.message, /Invalid request signature/, nonce);
  }
});

test('extra body field (correctly signed) -> 400', async () => {
  const out = await n8nVerify(backendSign({ ...BODY, command: 'rm -rf /' }));
  assert.equal(out.valid, false);
  assert.equal(out.http_status, 400);
  assert.match(out.response.message, /unexpected fields: command/);
});

test('replayed nonce -> 409', async () => {
  const staticData = {}; // shared like n8n workflow static data
  const req = backendSign(BODY);
  const first = await n8nVerify(req, { staticData });
  assert.equal(first.valid, true, JSON.stringify(first.response));
  const second = await n8nVerify(req, { staticData });
  assert.equal(second.valid, false);
  assert.equal(second.http_status, 409);
  assert.match(second.response.message, /Replayed request/);
});

test('missing signing secret in n8n -> 503', async () => {
  for (const env of [{ REMEDIATION_EXECUTION_MODE: 'simulate' }, { ...ENV, MACHINE_SIGNING_SECRET: '' }, { ...ENV, MACHINE_SIGNING_SECRET: 'too-short' }]) {
    const out = await n8nVerify(backendSign(BODY), { env });
    assert.equal(out.valid, false);
    assert.equal(out.http_status, 503);
    assert.match(out.response.message, /not configured/);
  }
});

test('disabled execution mode -> 503 (verifier output + workflow 06 routing)', async () => {
  // 1. The real verifier accepts the request but marks it disabled (the default).
  for (const env of [{ MACHINE_SIGNING_SECRET: SECRET }, { MACHINE_SIGNING_SECRET: SECRET, REMEDIATION_EXECUTION_MODE: 'disabled' }]) {
    const out = await n8nVerify(backendSign(BODY), { env });
    assert.equal(out.valid, true);
    assert.equal(out.execution_mode, 'disabled');
    assert.equal(out.execution_available, false);
  }
  // executor mode without EXECUTOR_URL / EXECUTOR_SIGNING_SECRET also refuses.
  for (const extra of [{}, { EXECUTOR_URL: 'http://host.docker.internal:9095' }, { EXECUTOR_URL: 'http://x:9095', EXECUTOR_SIGNING_SECRET: 'too-short' }]) {
    const out = await n8nVerify(backendSign(BODY), { env: { MACHINE_SIGNING_SECRET: SECRET, REMEDIATION_EXECUTION_MODE: 'executor', ...extra } });
    assert.equal(out.execution_mode, 'disabled');
    assert.equal(out.execution_available, false);
  }
  // 2. Routing in the generated workflow: valid -> "Execution available?" ->
  //    (false) -> "Execution blocked response" (503) -> "Respond 503".
  const wf = JSON.parse(readFileSync(new URL('../workflows/06-remediation.json', import.meta.url), 'utf8'));
  const node = (name) => wf.nodes.find((n) => n.name === name);
  const next = (name, output) => (wf.connections[name].main[output] || []).map((c) => c.node);
  assert.deepEqual(next('Verify signature and payload', 0), ['Request valid?']);
  assert.deepEqual(next('Request valid?', 0), ['Execution available?']);
  const cond = node('Execution available?').parameters.conditions.conditions[0];
  assert.equal(cond.leftValue, '={{ $json.execution_available }}');
  assert.equal(cond.operator.operation, 'true');
  assert.deepEqual(next('Execution available?', 1), ['Execution blocked response']);
  const status = node('Execution blocked response').parameters.assignments.assignments.find((a) => a.name === 'http_status');
  assert.equal(status.value, '={{ 503 }}');
  assert.deepEqual(next('Execution blocked response', 0), ['Respond 503']);
  assert.equal(node('Respond 503').parameters.options.responseCode, '={{ $json.http_status }}');
  // The run is not started on this path: "Sign start request" is only on the true branch.
  assert.deepEqual(next('Execution available?', 0), ['Sign start request']);
});
