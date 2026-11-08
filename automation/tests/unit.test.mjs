// Unit tests for the Code node scripts and the generated workflow files.
// Run: cd automation && npm test   (no n8n needed)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHmac } from 'node:crypto';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { runCodeNode } from './code-node-harness.mjs';
import { buildAll, WF, teamDir } from '../scripts/build-workflows.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SECRET = 'unit-test-only-secret-0123456789abcdefghij';
const sign = (raw, { ts = Math.floor(Date.now() / 1000), nonce = 'nonce-' + Math.random().toString(36).slice(2, 14) + 'abcdef', path = '/webhook/remediation', secret = SECRET } = {}) => ({
  'x-dc-timestamp': String(ts), 'x-dc-nonce': nonce,
  'x-dc-signature': 'sha256=' + createHmac('sha256', secret).update([ts, nonce, 'POST', path, raw].join('.'), 'utf8').digest('hex'),
});
const RUN = '11111111-1111-4111-8111-111111111111';
const INC = '22222222-2222-4222-8222-222222222222';

// ---------- generated workflow files ----------
const ALLOWED = {
  'n8n-nodes-base.code': [2], 'n8n-nodes-base.httpRequest': [4.2], 'n8n-nodes-base.if': [2.2], 'n8n-nodes-base.switch': [3.2],
  'n8n-nodes-base.set': [3.4], 'n8n-nodes-base.merge': [3], 'n8n-nodes-base.webhook': [2], 'n8n-nodes-base.respondToWebhook': [1.1],
  'n8n-nodes-base.executeWorkflow': [1.2], 'n8n-nodes-base.executeWorkflowTrigger': [1.1], 'n8n-nodes-base.wait': [1.1],
  'n8n-nodes-base.errorTrigger': [1], 'n8n-nodes-base.manualTrigger': [1], 'n8n-nodes-base.noOp': [1], 'n8n-nodes-base.stickyNote': [1],
};

test('committed workflow JSON files (and team copies) are up to date with the sources', () => {
  for (const { meta, json } of buildAll()) {
    const expected = JSON.parse(JSON.stringify(json));
    const stale = ' is stale: run npm run build';
    assert.deepEqual(JSON.parse(readFileSync(join(ROOT, 'workflows', meta.file), 'utf8')), expected, meta.file + stale);
    const copy = join('team-workflows', teamDir(meta.owner), 'workflows', meta.file);
    assert.deepEqual(JSON.parse(readFileSync(join(ROOT, copy), 'utf8')), expected, copy + stale);
    for (const n of json.nodes) {
      const text = String(n.parameters.jsCode || '') + String(n.parameters.content || '');
      assert.ok(!text.includes('\r'), meta.file + ' / ' + n.name + ': generated code must use LF line endings only');
    }
  }
});

test('every workflow is a valid export: known node types/versions, valid links, error workflow set', () => {
  for (const { meta, json } of buildAll()) {
    assert.equal(json.id, meta.id);
    const names = new Set();
    for (const n of json.nodes) {
      assert.ok(!names.has(n.name), meta.file + ': duplicate node ' + n.name);
      names.add(n.name);
      assert.ok(ALLOWED[n.type], meta.file + ': unexpected node type ' + n.type);
      assert.ok(ALLOWED[n.type].includes(n.typeVersion), meta.file + ': ' + n.type + ' v' + n.typeVersion);
      assert.match(n.id, /^[0-9a-f-]{36}$/);
    }
    for (const [from, c] of Object.entries(json.connections)) {
      assert.ok(names.has(from), meta.file + ': link from unknown ' + from);
      for (const outs of c.main) for (const l of outs) assert.ok(names.has(l.node), meta.file + ': link to unknown ' + l.node);
    }
    if (meta.id !== WF.errors.id) assert.equal(json.settings.errorWorkflow, WF.errors.id);
    for (const n of json.nodes.filter((x) => x.type === 'n8n-nodes-base.executeWorkflow')) {
      assert.ok(Object.values(WF).some((w) => w.id === n.parameters.workflowId.value), 'sub-workflow id exists');
    }
  }
});

test('Code nodes only use globals available in the n8n 2.x task-runner sandbox', () => {
  for (const { meta, json } of buildAll()) {
    for (const n of json.nodes.filter((x) => x.type === 'n8n-nodes-base.code')) {
      assert.doesNotMatch(n.parameters.jsCode, /new URLSearchParams|\bfetch\(|process\.env/, meta.file + ' / ' + n.name);
    }
  }
});

test('no secrets in the workflow files and no service_role usage', () => {
  for (const { meta, json } of buildAll()) {
    const text = JSON.stringify(json);
    assert.doesNotMatch(text, /gsk_[A-Za-z0-9]{10,}|ghp_[A-Za-z0-9]{20,}|service_role|SUPABASE_/i, meta.file);
    assert.doesNotMatch(text, /Bearer [A-Za-z0-9]{10,}/, meta.file);
    for (const n of json.nodes) for (const c of Object.values(n.credentials || {})) assert.deepEqual(Object.keys(c).sort(), ['id', 'name']);
  }
});

test('AI output never reaches an executing node: workflow 05 has no path to remediation', () => {
  const rca = buildAll().find((w) => w.meta.id === WF.rca.id).json;
  assert.ok(!JSON.stringify(rca).includes(WF.remediation.id), '05 must not call 06');
  // The only backend path 05 builds is the analysis endpoint.
  const paths = rca.nodes.filter((n) => n.type === 'n8n-nodes-base.code')
    .flatMap((n) => [...n.parameters.jsCode.matchAll(/const path = ([^;]+);/g)].map((m) => m[1]));
  assert.deepEqual(paths, ["'/api/machine/investigations/' + d.investigation_id + '/analysis'"]);
});

// ---------- 06 remediation request verification ----------
const verify = (body, headers, env = {}, staticData = {}) => runCodeNode('06-remediation/verify-request.js', {
  items: [{ headers, body: JSON.parse(body) }],
  binary: { data: { data: Buffer.from(body).toString('base64'), mimeType: 'application/json' } },
  env: { MACHINE_SIGNING_SECRET: SECRET, REMEDIATION_EXECUTION_MODE: 'simulate', ...env },
  staticData,
});

test('06 accepts a correctly signed, fresh request', async () => {
  const raw = JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart' });
  const [o] = await verify(raw, sign(raw));
  assert.equal(o.valid, true);
  assert.equal(o.execution_mode, 'simulate');
});

test('06 execution mode defaults to disabled (integration BLOCKED)', async () => {
  const raw = JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart' });
  const [o] = await verify(raw, sign(raw), { REMEDIATION_EXECUTION_MODE: '' });
  assert.equal(o.execution_mode, 'disabled');
});

test('06 rejects tampered body, wrong secret, stale time, replay, bad fields, missing secret', async () => {
  const raw = JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart' });
  const h = sign(raw);
  const tampered = raw.replace('restart', 'rollback');
  assert.equal((await verify(tampered, h))[0].http_status, 401);
  assert.equal((await verify(raw, sign(raw, { secret: 'another-secret-another-secret-another!!' })))[0].http_status, 401);
  assert.equal((await verify(raw, sign(raw, { ts: Math.floor(Date.now() / 1000) - 400 })))[0].http_status, 401);
  const store = {};
  const h2 = sign(raw);
  assert.equal((await verify(raw, h2, {}, store))[0].valid, true);
  assert.equal((await verify(raw, h2, {}, store))[0].http_status, 409);
  const extra = JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart', shell: 'reboot' });
  assert.equal((await verify(extra, sign(extra)))[0].http_status, 400);
  const badAction = JSON.stringify({ playbook_run_id: RUN, incident_id: INC, action_type: 'restart_service' });
  assert.equal((await verify(badAction, sign(badAction)))[0].http_status, 400);
  assert.equal((await verify(raw, sign(raw), { MACHINE_SIGNING_SECRET: '' }))[0].http_status, 503);
  assert.equal((await verify(raw, {}))[0].http_status, 401);
});

test('06 check-start uses the database action, not the webhook action', async () => {
  const signed = { playbook_run_id: RUN, incident_id: INC, requested_action: 'scale', execution_mode: 'simulate', request: {} };
  const [o] = await runCodeNode('06-remediation/check-start.js', {
    items: [{ statusCode: 200, body: { data: { status: 'running', incident_id: INC, action_type: 'restart' } } }],
    nodes: { 'Sign start request': [signed] },
  });
  assert.equal(o.started, false);
  assert.equal(o.started_but_rejected, true);
  assert.equal(o.http_status, 409);
  const [refused] = await runCodeNode('06-remediation/check-start.js', {
    items: [{ statusCode: 409, body: { success: false, message: 'The run is pending, not approved.' } }],
    nodes: { 'Sign start request': [signed] },
  });
  assert.equal(refused.started, false);
  assert.equal(refused.http_status, 409);
});

// ---------- 05 AI validation ----------
const rcaResponse = (obj) => ({ statusCode: 200, body: { model: 'm', choices: [{ message: { content: typeof obj === 'string' ? obj : JSON.stringify(obj) } }] } });
const goodRca = { summary: 's', root_cause: 'r', severity: 'high', confidence: 0.8, confirmed_findings: ['a'], possible_causes: ['b'], evidence: ['e'], recommended_action: 'rollback', recommendations: [] };
const prev = { ctx: { incident_id: INC, investigation_id: null, service_name: 'svc' }, model: 'm', source_status: [], partial: false };

test('05 validate-rca: accepts a valid answer, always requires human review', async () => {
  const [o] = await runCodeNode('05-root-cause/validate-rca.js', { items: [rcaResponse(goodRca)], nodes: { 'Build RCA prompt': [prev] } });
  assert.equal(o.status, 'analysis_ready');
  assert.equal(o.rca.requires_human_review, true);
  assert.equal(o.can_store, false, 'no investigation_id -> blocked');
  assert.match(o.store_blocker, /BD-2/);
});

test('05 validate-rca: rejects unsafe actions, bad severity, non-JSON and fenced JSON is accepted', async () => {
  const bad = await runCodeNode('05-root-cause/validate-rca.js', { items: [rcaResponse({ ...goodRca, recommended_action: 'kubectl delete pod x' })], nodes: { 'Build RCA prompt': [prev] } });
  assert.equal(bad[0].status, 'invalid_ai_response');
  const sev = await runCodeNode('05-root-cause/validate-rca.js', { items: [rcaResponse({ ...goodRca, severity: 'info' })], nodes: { 'Build RCA prompt': [prev] } });
  assert.equal(sev[0].status, 'invalid_ai_response');
  const text = await runCodeNode('05-root-cause/validate-rca.js', { items: [rcaResponse('the cause is X')], nodes: { 'Build RCA prompt': [prev] } });
  assert.equal(text[0].status, 'invalid_ai_response');
  const fenced = await runCodeNode('05-root-cause/validate-rca.js', { items: [rcaResponse('```json\n' + JSON.stringify({ ...goodRca, recommended_action: null }) + '\n```')], nodes: { 'Build RCA prompt': [prev] } });
  assert.equal(fenced[0].status, 'analysis_ready');
  assert.equal(fenced[0].rca.recommended_action, null);
});

test('05 combine-evidence distinguishes no evidence from unavailable sources', async () => {
  const ctx = { incident_id: null };
  const r = (source, status) => ({ source, status, ok: ['evidence_found', 'no_evidence'].includes(status) });
  const run = (items) => runCodeNode('05-root-cause/combine-evidence.js', { items, nodes: { 'Validate RCA input': [ctx] } });
  assert.equal((await run([r('logs', 'no_evidence'), r('metrics', 'no_evidence'), r('deployments', 'no_evidence')]))[0].decision, 'no_evidence');
  assert.equal((await run([r('logs', 'unavailable'), r('metrics', 'unavailable'), { error: 'boom' }]))[0].decision, 'sources_unavailable');
  const partial = (await run([r('logs', 'evidence_found'), { error: 'sub-workflow crashed' }]))[0];
  assert.equal(partial.decision, 'analyze');
  assert.equal(partial.partial, true);
  assert.equal(partial.sources.find((s) => s.source === 'metrics').status, 'workflow_failed');
});

// ---------- 01 alert intake ----------
const alert = JSON.parse(readFileSync(join(ROOT, 'test-data', 'sample-alert.json'), 'utf8'));

test('01 parse: maps the sample alert, severities and rejects bad alerts', async () => {
  const [o] = await runCodeNode('01-alert-intake/parse-alerts.js', { items: [{ body: alert }] });
  assert.equal(o.valid, true);
  assert.equal(o.alerts[0].service_name, 'checkout-api');
  assert.equal(o.alerts[0].severity, 'critical');
  const warn = structuredClone(alert); warn.alerts[0].labels.severity = 'warning';
  assert.equal((await runCodeNode('01-alert-intake/parse-alerts.js', { items: [{ body: warn }] }))[0].alerts[0].severity, 'medium');
  const noSvc = structuredClone(alert); delete noSvc.alerts[0].labels.service;
  const [bad] = await runCodeNode('01-alert-intake/parse-alerts.js', { items: [{ body: noSvc }] });
  assert.equal(bad.valid, false);
  assert.equal(bad.http_status, 400);
});

test('01 dedupe: the same occurrence is processed once, a new startsAt is new', async () => {
  const staticData = {};
  const [parsed] = await runCodeNode('01-alert-intake/parse-alerts.js', { items: [{ body: alert }] });
  const first = (await runCodeNode('01-alert-intake/dedupe.js', { items: [parsed], staticData }))[0];
  const second = (await runCodeNode('01-alert-intake/dedupe.js', { items: [parsed], staticData }))[0];
  assert.equal(first.response.new_alerts, 1);
  assert.equal(second.response.new_alerts, 0);
  assert.equal(second.response.duplicate_alerts, 1);
  const again = structuredClone(parsed); again.alerts[0].started_at = '2026-11-08T12:00:00.000Z';
  assert.equal((await runCodeNode('01-alert-intake/dedupe.js', { items: [again], staticData }))[0].response.new_alerts, 1);
});

// ---------- 07 recovery ----------
test('07 plan: without an error-rate check, recovery cannot be confirmed (unable_to_verify)', async () => {
  const [o] = await runCodeNode('07-recovery-check/plan.js', { items: [{ incident_id: INC, playbook_run_id: RUN, service_name: 'svc' }], env: { PROMETHEUS_URL: 'http://prom:9090' } });
  assert.equal(o.can_verify, false);
  assert.equal(o.verdict, 'unable_to_verify');
});

test('07 evaluate: healthy needs every signal; last attempt without data is unable_to_verify', async () => {
  const state = { attempt: 1, max_checks: 1, checks: [] };
  const vec = (v) => ({ statusCode: 200, body: { status: 'success', data: { result: v === null ? [] : [{ value: [0, String(v)] }] } } });
  const q = (name, extra) => ({ name, healthy_if: name === 'up' ? 'equals_1' : 'lte', threshold: name === 'up' ? undefined : 0.05, ...extra });
  const ok = await runCodeNode('07-recovery-check/evaluate-health.js', { items: [{ ...vec(1), state, check: q('up') }, { ...vec(0.01), state, check: q('error_rate') }] });
  assert.equal(ok[0].verdict, 'recovered');
  const bad = await runCodeNode('07-recovery-check/evaluate-health.js', { items: [{ ...vec(1), state, check: q('up') }, { ...vec(0.3), state, check: q('error_rate') }] });
  assert.equal(bad[0].verdict, 'not_recovered');
  const none = await runCodeNode('07-recovery-check/evaluate-health.js', { items: [{ ...vec(null), state, check: q('up') }] });
  assert.equal(none[0].verdict, 'unable_to_verify');
  const notLast = await runCodeNode('07-recovery-check/evaluate-health.js', { items: [{ ...vec(0), state: { ...state, max_checks: 3 }, check: q('up') }] });
  assert.equal(notLast[0].done, false);
});

// ---------- 09 error handler ----------
test('09 summary is redacted and classifies retryable errors', async () => {
  const [o] = await runCodeNode('09-error-handler/summarize-error.js', {
    items: [{ execution: { id: '7', error: { message: 'Request failed: ETIMEDOUT using token=ghp_abcdefghijklmnopqrstuvwxyz123456 key gsk_abcdefghijklmnop' }, lastNodeExecuted: 'Groq: RCA' }, workflow: { id: 'x', name: '05 - Root Cause Analysis' } }],
    env: {},
  });
  assert.doesNotMatch(JSON.stringify(o), /ghp_abc|gsk_abc/);
  assert.equal(o.retryable, true);
  assert.equal(o.notify, false, 'no https webhook configured');
  const [perm] = await runCodeNode('09-error-handler/summarize-error.js', { items: [{ execution: { error: { message: 'HTTP 401 Unauthorized' } }, workflow: { name: 'w' } }], env: { ERROR_NOTIFY_WEBHOOK_URL: 'https://hooks.slack.com/services/T/B/X' } });
  assert.equal(perm.retryable, false);
  assert.equal(perm.notify, true);
});

// ---------- 02 logs ----------
test('02 analyze: counts errors, groups repeats and redacts secrets', async () => {
  const req = { ctx: { incident_id: null, service_name: 'checkout-api' }, window: { start: 'a', end: 'b' }, limit: 200 };
  const body = JSON.parse(readFileSync(join(ROOT, 'test-data', 'sample-logs.json'), 'utf8'));
  const [o] = await runCodeNode('02-log-analysis/analyze-logs.js', { items: [{ statusCode: 200, body }], nodes: { 'Build LogQL query': [req] } });
  assert.equal(o.status, 'evidence_found');
  assert.ok(o.findings.some((f) => /Repeated message \(4x\)/.test(f)), o.findings.join('\n'));
  assert.doesNotMatch(JSON.stringify(o), /abcd1234secret/);
});
