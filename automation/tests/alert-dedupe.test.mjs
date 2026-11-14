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
// "Create incident": the real (BLOCKED) node, or a stand-in for the future BD-1 call.
const create = async (deduped, outcome) => {
  const items = await runCodeNode('01-alert-intake/create-incident.js', { items: [deduped] });
  if (outcome === 'blocked') return items;
  return items.map((i) => ({ ...i, incident_status: outcome, incident_created: outcome === 'created', incident_id: outcome === 'created' ? '22222222-2222-4222-8222-222222222222' : null }));
};
const confirm = (items, staticData) => runCodeNode('01-alert-intake/confirm-processing.js', { items, staticData });

// One full execution of the dedupe part of workflow 01 for a payload.
async function deliver(body, staticData, outcome = 'blocked', env) {
  const d = await dedupe(await parse(body), staticData, env);
  const confirmed = d.alerts.length ? await confirm(await create(d, outcome), staticData) : [];
  return { response: d.response, duplicates: d.duplicates, confirmed };
}
const withAlert = (changes) => {
  const b = structuredClone(sample);
  Object.assign(b.alerts[0], changes);
  return b;
};

test('N-3: the first alert is processed and, with incident creation not available yet (BD-1), confirmed', async () => {
  const s = {};
  const r = await deliver(sample, s);
  assert.equal(r.response.new_alerts, 1);
  assert.equal(r.confirmed[0].incident_status, 'blocked');
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
  const items = (await create(d, 'blocked')).map((i) => ({ ...i, incident_status: undefined }));
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
  assert.deepEqual(out('Create incident (backend) – BLOCKED'), [['Confirm alert processing']]);
  assert.deepEqual(out('Confirm alert processing'), [['Run 05 Root Cause']]);
  assert.deepEqual(out('Respond 202'), [['Create incident (backend) – BLOCKED']]);
});
