// I-7: readiness detection and safe response handling of the n8n integration
// test (tests/integration/run-n8n-integration.mjs). No n8n, no network.
// Run: cd automation && node --test tests/integration-response.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseBody, isWebhookReady, jsonField, messageOf, jsonText, describeProbe } from './integration/http-response.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const RUNNER = readFileSync(join(ROOT, 'tests', 'integration', 'run-n8n-integration.mjs'), 'utf8');
// A response as post() in the runner builds it: { status, json: parseBody(text) }.
const resp = (status, text) => ({ status, json: parseBody(text) });

test('I-7 A: HTTP 503 "Database is not ready" is not readiness', () => {
  const r = resp(503, JSON.stringify({ code: 503, message: 'Database is not ready!', stacktrace: 'ResponseError: Database is not ready!' }));
  assert.equal(isWebhookReady(r), false);
  assert.equal(messageOf(r), 'Database is not ready!');
  assert.equal(describeProbe({ ...r, message: messageOf(r) }), 'HTTP 503 Database is not ready!');
});

test('I-7 A: other not-ready answers are not readiness either', () => {
  for (const status of [404, 500, 502, 503, 504, 400, 401, 302]) assert.equal(isWebhookReady({ status }), false, 'HTTP ' + status);
  for (const probe of [null, undefined, {}, { status: 'abc' }, { status: NaN }]) assert.equal(isWebhookReady(probe), false, JSON.stringify(probe));
  assert.equal(describeProbe(null), 'no response (connection failed)');
});

test('I-7 A: a valid ready response is accepted', () => {
  // What the harness webhook answers when it is registered: 200 with the 02 result.
  const r = resp(200, JSON.stringify([{ source: 'logs', status: 'invalid_input', ok: false }]));
  assert.equal(isWebhookReady(r), true);
  for (const status of [200, 201, 202, 204]) assert.equal(isWebhookReady({ status }), true, 'HTTP ' + status);
});

test('I-7 B: invalid JSON does not crash and has no fields', () => {
  const r = resp(502, '<html>Bad Gateway</html>');
  assert.equal(r.json, '<html>Bad Gateway</html>', 'raw text is kept for the failure detail');
  assert.equal(jsonField(r, 'message'), undefined);
  assert.equal(messageOf(r), '');
  assert.equal(/Replayed/.test(messageOf(r)), false);
});

test('I-7 B: missing or null JSON body does not crash', () => {
  for (const r of [resp(409, ''), resp(409, '   '), resp(409, undefined), resp(409, 'null'), { status: 409 }, { status: 409, json: null }, null, undefined]) {
    assert.equal(jsonField(r, 'message'), undefined, JSON.stringify(r));
    assert.equal(messageOf(r), '');
    assert.equal(jsonField(r, 'new_alerts'), undefined);
  }
  assert.equal(parseBody(''), undefined);
  assert.equal(parseBody('null'), null);
});

test('I-7 B: missing message property and unexpected structures are handled', () => {
  assert.equal(messageOf(resp(409, JSON.stringify({ accepted: false }))), '', 'no message property');
  assert.equal(messageOf(resp(409, JSON.stringify({ message: 42 }))), '', 'non-string message');
  assert.equal(messageOf(resp(409, JSON.stringify({ message: { text: 'x' } }))), '');
  assert.equal(messageOf(resp(409, JSON.stringify(['Replayed request.']))), '', 'array body');
  assert.equal(messageOf(resp(409, '"Replayed request."')), '', 'JSON string body');
  assert.equal(messageOf(resp(409, '123')), '', 'JSON number body');
  assert.equal(jsonField(resp(202, '[{"new_alerts":1}]'), 'new_alerts'), undefined, 'array is not an object body');
  // Normal bodies still work.
  assert.equal(messageOf(resp(409, JSON.stringify({ accepted: false, message: 'Replayed request.' }))), 'Replayed request.');
  assert.equal(jsonField(resp(202, JSON.stringify({ accepted: true, new_alerts: 1 })), 'new_alerts'), 1);
  // jsonText never returns undefined, so .includes() cannot crash.
  assert.equal(jsonText(undefined), '');
  assert.equal(jsonText(['cpu is abnormal']).includes('cpu is abnormal'), true);
});

test('I-7: the integration runner uses the safe helpers', () => {
  assert.match(RUNNER, /from '\.\/http-response\.mjs'/);
  assert.match(RUNNER, /ready = isWebhookReady\(/, 'readiness must use isWebhookReady');
  assert.doesNotMatch(RUNNER, /status !== 404/, 'old readiness rule (anything but 404) must be gone');
  // No direct r.json.<field> access in code (comments excluded).
  const code = RUNNER.split(/\r?\n/).filter((l) => !/^\s*\/\//.test(l)).join('\n');
  assert.doesNotMatch(code, /\br\.json\.[A-Za-z_]/, 'use jsonField()/messageOf() instead of r.json.<field>');
  assert.doesNotMatch(code, /JSON\.stringify\([^)]*\)\.includes\(/, 'use jsonText() before .includes()');
  // Recorded backend calls: c.body is checked before its fields are read.
  const bodyReads = [...code.matchAll(/(.{0,12})c\.body\.(status|result)\b/g)];
  assert.ok(bodyReads.length > 0);
  for (const m of bodyReads) assert.match(m[1], /c\.body && $|c\.body\.result && $|&& $/, 'unguarded c.body access: ' + m[0]);
  assert.doesNotMatch(code, /(?<!c\.body\.result && )c\.body\.result\.simulated/, 'c.body.result must be checked before .simulated');
});
