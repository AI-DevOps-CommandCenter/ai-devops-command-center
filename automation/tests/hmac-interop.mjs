// Proves that the n8n signing code (automation/src/lib/hmac.js) produces
// signatures the REAL backend accepts, and vice versa.
// Uses backend/src/middleware/machine-auth.ts directly, so it needs the
// backend's dev dependencies (tsx). Run from the repository root:
//   npx --prefix backend tsx automation/tests/hmac-interop.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { computeSignature, buildSignedHeaders, machineAuth, createMemoryNonceStore } from '../../backend/src/middleware/machine-auth.ts';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const lib = new Function('require', 'Buffer', readFileSync(join(ROOT, 'src', 'lib', 'hmac.js'), 'utf8') + '\nreturn { signedBackendRequest, verifySignedRequest, hmacSignature };')(createRequire(import.meta.url), Buffer);
const SECRET = 'interop-test-secret-0123456789abcdefghijkl';

// 1. n8n -> backend: the request n8n builds passes the backend's real middleware.
const req = lib.signedBackendRequest({ MACHINE_SIGNING_SECRET: SECRET, BACKEND_BASE_URL: 'http://backend:3000' }, 'POST', '/api/machine/playbook-runs/11111111-1111-4111-8111-111111111111/start', { n8n_execution_id: '42', workflow_name: 'remediation' });
assert.equal(req.url, 'http://backend:3000/api/machine/playbook-runs/11111111-1111-4111-8111-111111111111/start');
const expected = computeSignature(SECRET, { timestamp: Number(req.headers['X-DC-Timestamp']), nonce: req.headers['X-DC-Nonce'], method: 'POST', path: req.path, body: req.body });
assert.equal(req.headers['X-DC-Signature'], expected, 'n8n signature must equal the backend computeSignature');

let status = 0; let nextCalled = false;
const fakeReq = { method: 'POST', originalUrl: req.path, rawBody: Buffer.from(req.body), get: (h) => ({ 'x-dc-timestamp': req.headers['X-DC-Timestamp'], 'x-dc-nonce': req.headers['X-DC-Nonce'], 'x-dc-signature': req.headers['X-DC-Signature'] })[h.toLowerCase()] };
const fakeRes = { status(s) { status = s; return this; }, json() { return this; } };
await machineAuth({ secret: SECRET, nonceStore: createMemoryNonceStore() })(fakeReq, fakeRes, () => { nextCalled = true; });
assert.equal(nextCalled, true, 'backend middleware must accept the n8n request (status ' + status + ')');

// 2. backend -> n8n: headers from the backend's buildSignedHeaders pass n8n's verification.
const body = JSON.stringify({ playbook_run_id: '11111111-1111-4111-8111-111111111111', incident_id: '22222222-2222-4222-8222-222222222222', action_type: 'restart', request_payload: {} });
const headers = buildSignedHeaders(SECRET, { method: 'POST', path: '/webhook/remediation', body, nonce: 'abcdefghijklmnop1234' });
const result = lib.verifySignedRequest(SECRET, headers, 'POST', '/webhook/remediation', body, {}, Date.now());
assert.deepEqual(result, { ok: true, status: 200, reason: null });

console.log('HMAC interop: PASS (n8n -> backend middleware accepted; backend -> n8n verified)');
