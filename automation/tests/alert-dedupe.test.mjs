// N-3: duplicate alert handling in workflow 01 ("Detect duplicate alerts" ->
// "Create incident" -> "Confirm alert processing"). The static data object is
// shared between the calls, like n8n's workflow static data.
// Run: cd automation && node --test tests/alert-dedupe.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { runCodeNode } from './code-node-harness.mjs';
import { buildAll, WF } from '../scripts/build-workflows.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const sample = JSON.parse(readFileSync(join(ROOT, 'test-data', 'sample-alert.json'), 'utf8'));

const parse = async (body) => (await runCodeNode('01-alert-intake/parse-alerts.js', { items: [{ body }] }))[0];
const dedupe = async (parsed, staticData, env = {}) => (await runCodeNode('01-alert-intake/dedupe.js', { items: [parsed], staticData, env }))[0];
// "Create incident" (BD-1): the real sign node, a simulated backend answer
// (201 created, 200 existing incident, or 500), then the real result node.
const BACKEND_ENV = { BACKEND_BASE_URL: 'http://backend.test', MACHINE_SIGNING_SECRET: 'test-only-machine-secret-0123456789abcdef' };
const INCIDENT = { incident_id: '22222222-2222-4222-8222-222222222222', investigation_id: '33333333-3333-4333-8333-333333333333' };
const create = async (deduped, outcome) => {
  const signed = await runCodeNode('01-alert-intake/sign-create-incident.js', { items: [deduped], env: BACKEND_ENV });
  const answer = outcome === 'created' ? { statusCode: 201, body: { data: { ...INCIDENT, created: true } } }
    : outcome === 'existing' ? { statusCode: 200, body: { data: { ...INCIDENT, created: false } } }
    : { statusCode: 500, body: { message: 'Failed to create incident.' } };
  return runCodeNode('01-alert-intake/incident-result.js', { items: signed.map(() => answer), nodes: { 'Sign create incident request': signed } });
};
const confirm = (items, staticData) => runCodeNode('01-alert-intake/confirm-processing.js', { items, staticData });

// One full execution of the dedupe part of workflow 01 for a payload.
async function deliver(body, staticData, outcome = 'created', env) {
  const d = await dedupe(await parse(body), staticData, env);
  const confirmed = d.alerts.length ? await confirm(await create(d, outcome), staticData) : [];
  return { response: d.response, duplicates: d.duplicates, confirmed };
}
const withAlert = (changes) => {
  const b = structuredClone(sample);
  Object.assign(b.alerts[0], changes);
  return b;
};

test('N-3: the first alert is processed and, once its incident is created (BD-1), confirmed', async () => {
  const s = {};
  const r = await deliver(sample, s);
  assert.equal(r.response.new_alerts, 1);
  assert.equal(r.confirmed[0].incident_status, 'created');
  assert.equal(r.confirmed[0].incident_id, INCIDENT.incident_id);
  assert.equal(r.confirmed[0].investigation_id, INCIDENT.investigation_id);
  assert.equal(r.confirmed[0].dedup_state, 'confirmed');
  const [key] = Object.keys(s.seenAlerts);
  assert.equal(s.seenAlerts[key].state, 'confirmed');
  assert.equal(key, 'a1b2c3d4e5f60718|' + new Date(sample.alerts[0].startsAt).toISOString());
});

test('N-3: a duplicate alert is skipped (existing behaviour preserved)', async () => {
  const s = {};
  await deliver(sample, s);
  const r = await deliver(sample, s);
  assert.equal(r.response.new_alerts, 0);
  assert.equal(r.response.duplicate_alerts, 1);
  assert.equal(r.duplicates[0].state, 'processed');
});

test('N-3: a successful incident creation is marked processed', async () => {
  const s = {};
  const r = await deliver(sample, s, 'created');
  assert.equal(r.confirmed[0].dedup_state, 'confirmed');
  assert.equal((await deliver(sample, s, 'created')).response.new_alerts, 0);
});

test('N-3: a failed incident creation releases the alert, so the next delivery is processed again', async () => {
  const s = {};
  const failed = await deliver(sample, s, 'failed');
  assert.equal(failed.response.new_alerts, 1);
  assert.equal(failed.confirmed[0].dedup_state, 'released');
  assert.deepEqual(s.seenAlerts, {}, 'nothing is remembered after a failure');
  const retry = await deliver(sample, s, 'created');
  assert.equal(retry.response.new_alerts, 1, 'the retry is processed');
  assert.equal(retry.confirmed[0].dedup_state, 'confirmed');
  assert.equal((await deliver(sample, s)).response.new_alerts, 0, 'and then it is a duplicate');
});

test('N-3: an unknown incident status is treated as a failure (fail-safe: retry allowed)', async () => {
  const s = {};
  const d = await dedupe(await parse(sample), s);
  const items = (await create(d, 'created')).map((i) => ({ ...i, incident_status: undefined }));
  assert.equal((await confirm(items, s))[0].dedup_state, 'released');
});

test('N-3: different fingerprints are processed independently', async () => {
  const s = {};
  await deliver(sample, s, 'failed');
  const other = withAlert({ fingerprint: 'ffff000011112222' });
  assert.equal((await deliver(other, s)).response.new_alerts, 1);
  assert.equal((await deliver(other, s)).response.new_alerts, 0);
  assert.equal((await deliver(sample, s)).response.new_alerts, 1, 'the failed first alert is not affected by the other one');
});

test('N-3: same fingerprint with a different startsAt is a new occurrence (existing contract)', async () => {
  const s = {};
  await deliver(sample, s);
  const later = withAlert({ startsAt: '2026-11-08T12:00:00Z' });
  assert.equal((await deliver(later, s)).response.new_alerts, 1);
  assert.equal((await deliver(later, s)).response.new_alerts, 0);
});

test('N-3: the same occurrence twice in ONE notification is processed once', async () => {
  const s = {};
  const body = structuredClone(sample);
  body.alerts.push(structuredClone(sample.alerts[0]));
  const r = await deliver(body, s);
  assert.equal(r.response.new_alerts, 1);
  assert.equal(r.response.duplicate_alerts, 1);
});

test('N-3: an alert whose processing is still pending is skipped as "in progress"; a stale pending entry expires', async () => {
  const s = {};
  const d = await dedupe(await parse(sample), s);
  assert.equal(d.response.new_alerts, 1);
  // The execution crashed before "Confirm alert processing": the entry stays pending.
  const inFlight = await dedupe(await parse(sample), s);
  assert.equal(inFlight.response.new_alerts, 0);
  assert.equal(inFlight.duplicates[0].state, 'in_progress');
  const key = Object.keys(s.seenAlerts)[0];
  s.seenAlerts[key].at = Date.now() - 16 * 60000; // older than DEDUP_PENDING_MINUTES (15)
  assert.equal((await dedupe(await parse(sample), s)).response.new_alerts, 1, 'processed again after the pending timeout');
  s.seenAlerts[key].at = Date.now() - 4 * 60000;
  assert.equal((await dedupe(await parse(sample), s, { DEDUP_PENDING_MINUTES: '3' })).response.new_alerts, 1, 'DEDUP_PENDING_MINUTES is configurable');
});

test('N-3: confirmed entries expire after DEDUP_WINDOW_MINUTES; entries of the previous version still count', async () => {
  const key = 'a1b2c3d4e5f60718|' + new Date(sample.alerts[0].startsAt).toISOString();
  const legacy = { seenAlerts: { [key]: Date.now() - 60000 } };
  assert.equal((await deliver(sample, legacy)).response.new_alerts, 0, 'a number (old format) = confirmed');
  const old = { seenAlerts: { [key]: { state: 'confirmed', at: Date.now() - 361 * 60000 } } };
  assert.equal((await deliver(sample, old)).response.new_alerts, 1, 'expired after 360 minutes');
  const garbage = { seenAlerts: { [key]: 'x', other: { state: 'weird', at: 1 } } };
  assert.equal((await deliver(sample, garbage)).response.new_alerts, 1, 'invalid entries are dropped');
  assert.ok(!('other' in garbage.seenAlerts));
});

test('N-3 LIMITATION: two deliveries processed at the same time are both processed (n8n static data is per execution)', async () => {
  // n8n gives each running execution its own copy of the static data and saves
  // it when the execution ends, so concurrent executions cannot see each other.
  // This test documents the behaviour; the fix is BD-1 idempotency in the database.
  const saved = {};
  const copyA = structuredClone(saved);
  const copyB = structuredClone(saved);
  const a = await deliver(sample, copyA);
  const b = await deliver(sample, copyB);
  assert.equal(a.response.new_alerts + b.response.new_alerts, 2, 'both concurrent executions process the alert');
});

test('N-3: workflow 01 wiring: create incident -> confirm -> run 05; the response is sent before', () => {
  const wf = buildAll().find((w) => w.meta.id === WF.intake.id).json;
  const out = (name) => wf.connections[name].main.map((o) => o.map((l) => l.node));
  assert.deepEqual(out('Respond 202'), [['Sign create incident request']]);
  assert.deepEqual(out('Sign create incident request'), [['Backend: create incident']]);
  assert.deepEqual(out('Backend: create incident'), [['Incident result']]);
  assert.deepEqual(out('Incident result'), [['Confirm alert processing']]);
  assert.deepEqual(out('Confirm alert processing'), [['Run 05 Root Cause']]);
});

test('BD-1: the signed request matches the backend contract (POST /api/machine/incidents)', async () => {
  const d = await dedupe(await parse(sample), {});
  const [signed] = await runCodeNode('01-alert-intake/sign-create-incident.js', { items: [d], env: BACKEND_ENV });
  assert.equal(signed.request.url, 'http://backend.test/api/machine/incidents');
  const body = JSON.parse(signed.request.body);
  assert.equal(body.fingerprint, sample.alerts[0].fingerprint);
  assert.equal(body.service_name, d.alerts[0].service_name);
  assert.ok(['critical', 'high', 'medium', 'low', 'info'].includes(body.severity));
  assert.ok(body.title.length >= 1 && body.title.length <= 300);
  assert.match(signed.request.headers['X-DC-Signature'], /^sha256=[0-9a-f]{64}$/);
});

test('BD-1: an existing incident for the alert (200) counts as created; a missing secret fails without a request', async () => {
  const d = await dedupe(await parse(sample), {});
  assert.equal((await create(d, 'existing'))[0].incident_status, 'created');
  const signed = await runCodeNode('01-alert-intake/sign-create-incident.js', { items: [d], env: {} });
  assert.equal(signed[0].request, null);
  const [r] = await runCodeNode('01-alert-intake/incident-result.js', { items: [{}], nodes: { 'Sign create incident request': signed } });
  assert.equal(r.incident_status, 'failed');
  assert.equal(r.incident_error.kind, 'not_configured');
});

// BD-4: workflow 08 reads the stored context and saves the validated draft.
test('BD-4: 08 signs the context GET and the postmortem POST; invalid drafts are not stored', async () => {
  const id = '22222222-2222-4222-8222-222222222222';
  const [ctx] = await runCodeNode('08-postmortem/sign-context.js', { items: [{ incident_id: id, status: 'recovered' }], env: BACKEND_ENV });
  assert.equal(ctx.request.url, `http://backend.test/api/machine/incidents/${id}/context`);
  assert.equal(ctx.request.method, 'GET');
  assert.equal(ctx.request.body, '');
  const [noId] = await runCodeNode('08-postmortem/sign-context.js', { items: [{ status: 'recovered' }], env: BACKEND_ENV });
  assert.equal(noId.skip_context, true);

  const stored = { incident: { id, service_name: 'sample-app' }, rca: { root_cause: 'rc' }, timeline: [{ time: 't', type: 'log', message: 'm' }] };
  const [collected] = await runCodeNode('08-postmortem/collect-context.js', {
    items: [{ statusCode: 200, body: { data: stored } }],
    nodes: { 'Sign context request': [ctx] },
  });
  assert.equal(collected.enough, true);
  assert.equal(collected.context.rca.root_cause, 'rc');
  assert.equal(collected.context.service_name, 'sample-app');

  const postmortem = { title: 't', summary: 's' };
  const [store] = await runCodeNode('08-postmortem/sign-store.js', { items: [{ incident_id: id, valid: true, postmortem }], env: BACKEND_ENV });
  assert.equal(store.request.url, `http://backend.test/api/machine/incidents/${id}/postmortem`);
  assert.deepEqual(JSON.parse(store.request.body), postmortem);
  const [res] = await runCodeNode('08-postmortem/store-result.js', {
    items: [{ statusCode: 201, body: { data: { postmortem_id: 'pm-1' } } }],
    nodes: { 'Sign store postmortem request': [store] },
  });
  assert.equal(res.stored, true);
  assert.equal(res.postmortem_id, 'pm-1');

  const [skip] = await runCodeNode('08-postmortem/sign-store.js', { items: [{ incident_id: id, valid: false, postmortem: null }], env: BACKEND_ENV });
  assert.equal(skip.skip_store, true);
  const [notStored] = await runCodeNode('08-postmortem/store-result.js', { items: [{}], nodes: { 'Sign store postmortem request': [skip] } });
  assert.equal(notStored.stored, false);
});
