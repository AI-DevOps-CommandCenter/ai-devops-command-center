#!/usr/bin/env node
// Replay protection / duplicate remediation requests (workflow 06) against a
// THROWAWAY n8n 2.40.5 instance running the REAL generated workflows, with the
// mock backend (tests/integration/mock-services.mjs). No Supabase, no real services.
// Own ports (n8n 5790/5791, mocks 4698/4699), own temp work dir; Supabase
// variables are removed from the environment passed to n8n.
//
// Run from automation/:  npm run test:n8n:replay   (about 3 minutes)
//
// KNOWN ISSUE (not fixed): check "S5 n8n nonce store kept BOTH nonces" FAILS on
// purpose. 06 keeps replay nonces in workflow static data, which n8n loads when an
// execution starts and saves (whole object, last writer wins) when it ends, so a
// nonce of one of two concurrent executions can be lost. The backend run state
// (start_playbook_run) is what prevents a second start today. See
// docs/automation-integration-requirements.md, known issue KI-1. Do NOT relax
// the S5 check: it must pass only once replay protection is atomic and shared.
// This script is deliberately NOT part of `npm test` or `npm run test:n8n`.
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import { buildAll, CRED } from '../../scripts/build-workflows.mjs';
import { startMocks } from './mock-services.mjs';
import { parseBody, messageOf, jsonField } from './http-response.mjs';

const WORK = mkdtempSync(join(tmpdir(), 'dc33-replay-it-'));
const N8N_JS = process.env.N8N_JS || join(spawnSync('npm', ['root', '-g'], { encoding: 'utf8', shell: process.platform === 'win32' }).stdout.trim(), 'n8n', 'bin', 'n8n');
// Own ports: never collides with the main integration runner (5690/4597-4599).
const PORT = 5790, BROKER = 5791, SVC = 4699, BACKEND = 4698;
const SECRET = 'replay-test-only-secret-0123456789abcdef';
const INC = '22222222-2222-4222-8222-222222222222';

// Inherit PATH etc., but never any Supabase setting from the developer's shell.
const baseEnv = Object.fromEntries(Object.entries(process.env).filter(([k]) => !/SUPABASE/i.test(k)));
const ENV = {
  ...baseEnv,
  N8N_USER_FOLDER: WORK, N8N_PORT: String(PORT), N8N_RUNNERS_BROKER_PORT: String(BROKER),
  N8N_ENCRYPTION_KEY: 'replay-test-encryption-key-not-secret',
  N8N_DIAGNOSTICS_ENABLED: 'false', N8N_PERSONALIZATION_ENABLED: 'false', N8N_VERSION_NOTIFICATIONS_ENABLED: 'false',
  N8N_BLOCK_ENV_ACCESS_IN_NODE: 'false', NODE_FUNCTION_ALLOW_BUILTIN: 'crypto',
  WEBHOOK_URL: `http://127.0.0.1:${PORT}/`,
  BACKEND_BASE_URL: `http://127.0.0.1:${BACKEND}`, MACHINE_SIGNING_SECRET: SECRET,
  GROQ_API_BASE_URL: `http://127.0.0.1:${SVC}/groq/openai/v1`, GROQ_MODEL: 'test-model', GROQ_TIMEOUT_MS: '3000',
  LOKI_URL: `http://127.0.0.1:${SVC}/loki`, LOKI_SERVICE_LABEL: 'service',
  PROMETHEUS_URL: `http://127.0.0.1:${SVC}/prom`, PROM_SERVICE_LABEL: 'job',
  PROM_QUERY_ERROR_RATE: 'sum(errrate{job="{{service}}"})', PROM_THRESHOLD_ERROR_RATE: '0.05',
  GITHUB_API_URL: `http://127.0.0.1:${SVC}/gh`, GITHUB_OWNER: 'acme', GITHUB_REPO: 'demo',
  RECOVERY_WAIT_SECONDS: '5', RECOVERY_MAX_CHECKS: '2',
  REMEDIATION_EXECUTION_MODE: 'simulate',
  BACKEND_TIMEOUT_MS: '1500', COMPLETE_RETRY_BASE_SECONDS: '1',
  ERROR_NOTIFY_WEBHOOK_URL: '',
};

const results = [];
const check = (name, cond, detail) => { results.push({ name, ok: !!cond }); console.log((cond ? '  PASS ' : '  FAIL ') + name + (cond ? '' : '\n       ' + String(JSON.stringify(detail)).slice(0, 800))); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const cli = (args) => new Promise((resolve) => {
  const p = spawn(process.execPath, [N8N_JS, ...args], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
  let out = ''; p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (out += d));
  p.on('close', (status) => resolve({ status, out }));
});

async function post(raw, headers) {
  const t0 = Date.now();
  const res = await fetch(`http://127.0.0.1:${PORT}/webhook/remediation`, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: raw });
  const text = await res.text().catch(() => '');
  return { status: res.status, json: parseBody(text), ms: Date.now() - t0 };
}
const signed = (body) => {
  const raw = JSON.stringify(body);
  const ts = Math.floor(Date.now() / 1000);
  const nonce = randomBytes(18).toString('base64url');
  const sig = 'sha256=' + createHmac('sha256', SECRET).update([ts, nonce, 'POST', '/webhook/remediation', raw].join('.'), 'utf8').digest('hex');
  return { raw, headers: { 'X-DC-Timestamp': String(ts), 'X-DC-Nonce': nonce, 'X-DC-Signature': sig } };
};
const brief = (r) => ({ http: r.status, accepted: jsonField(r, 'accepted'), message: messageOf(r) || jsonField(r, 'message') });

async function main() {
  console.log('replay-protection test, throwaway work dir: ' + WORK);
  const mocks = startMocks({ servicesPort: SVC, backendPort: BACKEND, secret: SECRET, backendTimeoutMs: 1500 });
  const evidence = {};
  // Every backend call is kept here (mocks.calls is drained into it).
  let seen = [];
  const pull = () => { seen = seen.concat(mocks.calls.splice(0)); return seen; };
  const backend = (run, kind) => pull().filter((c) => c.port === 'backend' && c.path === `/api/machine/playbook-runs/${run}/${kind}`);
  const stores = (run) => pull().filter((c) => c.port === 'backend' && c.path === '/api/machine/recovery-checks' && c.body && c.body.playbook_run_id === run);
  const newRun = () => { const run = randomUUID(); mocks.runs[run] = { status: 'approved', action_type: 'restart', incident_id: INC }; return run; };
  const body = (run) => ({ playbook_run_id: run, incident_id: INC, action_type: 'restart', request_payload: { service_name: 'checkout-api' } });
  // Wait until the run's execution has finished (recovery check stored), then
  // give n8n time to persist the execution (and its static data).
  const settle = async (runs) => { const end = Date.now() + 60000; while (Date.now() < end && !runs.every((r) => stores(r).length > 0)) await sleep(300); await sleep(4000); pull(); };
  const snapshot = (run) => ({
    start_calls: backend(run, 'start').length,
    start_calls_signed_ok: backend(run, 'start').filter((c) => c.auth === 'ok').length,
    complete_calls: backend(run, 'complete').length,
    run_state: { ...mocks.runs[run] },
  });

  // ---- import + publish the real workflows into the throwaway n8n
  const wfDir = join(WORK, 'import'); mkdirSync(wfDir, { recursive: true });
  const all = buildAll().map((w) => w.json);
  all.forEach((w) => writeFileSync(join(wfDir, w.id + '.json'), JSON.stringify(w)));
  writeFileSync(join(WORK, 'creds.json'), JSON.stringify([
    { id: CRED.groq.id, name: CRED.groq.name, type: 'httpHeaderAuth', data: { name: 'Authorization', value: 'Bearer test-groq-key' } },
    { id: CRED.github.id, name: CRED.github.name, type: 'httpHeaderAuth', data: { name: 'Authorization', value: 'Bearer test-gh-token' } },
    { id: CRED.alertmanager.id, name: CRED.alertmanager.name, type: 'httpHeaderAuth', data: { name: 'Authorization', value: 'Bearer test-alert-token' } },
  ]));
  let r = await cli(['import:credentials', '--input=' + join(WORK, 'creds.json')]);
  check('setup: import credentials (test-only values)', r.status === 0, r.out.slice(-400));
  r = await cli(['import:workflow', '--separate', '--input=' + wfDir]);
  check('setup: import ' + all.length + ' generated workflows', r.status === 0, r.out.slice(-400));
  for (const w of all) { r = await cli(['publish:workflow', '--id=' + w.id]); if (r.status !== 0) check('setup: publish ' + w.id, false, r.out.slice(-400)); }

  const server = spawn(process.execPath, [N8N_JS, 'start'], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
  let log = ''; server.stdout.on('data', (d) => (log += d)); server.stderr.on('data', (d) => (log += d));
  let ready = false;
  for (let i = 0; i < 120 && !ready; i++) {
    await sleep(2000);
    // Probe with an UNSIGNED request: 401 from the verifier means the webhook is live.
    const p = await fetch(`http://127.0.0.1:${PORT}/webhook/remediation`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' }).catch(() => null);
    ready = !!p && p.status === 401;
  }
  check('setup: n8n started, /webhook/remediation live (unsigned probe -> 401)', ready, log.slice(-1500));
  if (!ready) return finish(server, mocks, evidence);
  pull(); seen = [];

  // ===== Scenario 1-4: one valid request, then the EXACT same request after it finished
  console.log('\nS1 sequential: valid request, then exact replay after the execution finished');
  const run1 = newRun();
  const s1 = signed(body(run1));
  const a = await post(s1.raw, s1.headers);
  check('S1 first valid signed request -> 202 accepted', a.status === 202 && jsonField(a, 'accepted') === true, brief(a));
  await settle([run1]);
  const startsBefore = backend(run1, 'start').length;
  const b = await post(s1.raw, s1.headers); // identical timestamp, nonce, signature, body
  await sleep(3000); pull();
  check('S1 exact replay -> 409 "Replayed request." (n8n nonce store)', b.status === 409 && /Replayed request/.test(brief(b).message || ''), brief(b));
  check('S1 replay made NO backend call (/start count unchanged)', backend(run1, 'start').length === startsBefore, backend(run1, 'start').length);
  const snap1 = snapshot(run1);
  check('S1 /start called exactly once and succeeded once', snap1.start_calls === 1 && snap1.start_calls_signed_ok === 1, snap1);
  check('S1 run executed once: status success, 1 completion', snap1.run_state.status === 'success' && snap1.run_state.completions === 1, snap1);
  evidence.S1 = { first: brief(a), replay: brief(b), ...snap1 };

  // ===== Existing-case variant: exact replay while the first execution is STILL running
  console.log('\nS2 sequential: exact replay while the first execution is still running');
  const run2 = newRun();
  const s2 = signed(body(run2));
  const c1 = await post(s2.raw, s2.headers);
  const c2 = await post(s2.raw, s2.headers);
  await settle([run2]);
  const snap2 = snapshot(run2);
  check('S2 first -> 202', c1.status === 202, brief(c1));
  check('S2 in-flight replay rejected with 409', c2.status === 409, brief(c2));
  console.log('  OBSERVED S2 replay rejected by: ' + (/Replayed request/.test(brief(c2).message || '') ? 'n8n nonce store' : 'backend run state (' + brief(c2).message + ')'));
  check('S2 run started successfully only once (one run.exec, 1 completion, status success)', snap2.run_state.status === 'success' && snap2.run_state.completions === 1 && snap2.complete_calls === 1, snap2);
  evidence.S2 = { first: brief(c1), replay: brief(c2), ...snap2 };

  // ===== Scenario 5: two identical requests sent concurrently
  console.log('\nS3 concurrent: two identical signed requests at the same time');
  const run3 = newRun();
  const s3 = signed(body(run3));
  const both = await Promise.all([post(s3.raw, s3.headers), post(s3.raw, s3.headers)]);
  await settle([run3]);
  const snap3 = snapshot(run3);
  const statuses3 = both.map((x) => x.status).sort();
  check('S3 exactly one 202 and one 409', JSON.stringify(statuses3) === JSON.stringify([202, 409]), both.map(brief));
  const rej3 = both.find((x) => x.status !== 202) || {};
  console.log('  OBSERVED S3 duplicate rejected by: ' + (/Replayed request/.test(messageOf(rej3) || '') ? 'n8n nonce store' : 'backend run state (' + (messageOf(rej3) || jsonField(rej3, 'message')) + ')'));
  console.log('  OBSERVED S3 /start calls reaching the backend: ' + snap3.start_calls);
  check('S3 run executed once: status success, exactly 1 completion', snap3.run_state.status === 'success' && snap3.run_state.completions === 1 && snap3.complete_calls === 1, snap3);
  const s3replay = await post(s3.raw, s3.headers);
  await sleep(3000); pull();
  check('S3 third copy after both executions ended -> 409 Replayed (n8n), no new /start', s3replay.status === 409 && /Replayed request/.test(brief(s3replay).message || '') && backend(run3, 'start').length === snap3.start_calls, { r: brief(s3replay), starts: backend(run3, 'start').length });
  evidence.S3 = { responses: both.map(brief), later_replay: brief(s3replay), ...snap3 };

  // ===== Burst: five identical requests concurrently
  console.log('\nS4 concurrent burst: five identical signed requests');
  const run4 = newRun();
  const s4 = signed(body(run4));
  const five = await Promise.all(Array.from({ length: 5 }, () => post(s4.raw, s4.headers)));
  await settle([run4]);
  const snap4 = snapshot(run4);
  check('S4 exactly one 202, four 409', five.filter((x) => x.status === 202).length === 1 && five.filter((x) => x.status === 409).length === 4, five.map(brief));
  console.log('  OBSERVED S4 /start calls reaching the backend: ' + snap4.start_calls + ' (n8n nonce store rejected ' + five.filter((x) => /Replayed request/.test(messageOf(x) || '')).length + ')');
  check('S4 run executed once (1 completion)', snap4.run_state.status === 'success' && snap4.run_state.completions === 1 && snap4.complete_calls === 1, snap4);
  evidence.S4 = { responses: five.map(brief), ...snap4 };

  // ===== Nonce-store durability: two DIFFERENT valid requests concurrently, then replay each
  console.log('\nS5 nonce store after two concurrent executions with different nonces');
  const run5a = newRun(), run5b = newRun();
  const s5a = signed(body(run5a)), s5b = signed(body(run5b));
  const pair = await Promise.all([post(s5a.raw, s5a.headers), post(s5b.raw, s5b.headers)]);
  check('S5 both distinct requests accepted (202, 202)', pair.every((x) => x.status === 202), pair.map(brief));
  await settle([run5a, run5b]);
  const startsA = backend(run5a, 'start').length, startsB = backend(run5b, 'start').length;
  const ra = await post(s5a.raw, s5a.headers);
  const rb = await post(s5b.raw, s5b.headers);
  await sleep(3000); pull();
  const reachedA = backend(run5a, 'start').length - startsA, reachedB = backend(run5b, 'start').length - startsB;
  console.log(`  OBSERVED S5 replay A -> ${ra.status} "${brief(ra).message}" (new /start calls: ${reachedA})`);
  console.log(`  OBSERVED S5 replay B -> ${rb.status} "${brief(rb).message}" (new /start calls: ${reachedB})`);
  check('S5 both replays rejected with 409', ra.status === 409 && rb.status === 409, [brief(ra), brief(rb)]);
  check('S5 n8n nonce store kept BOTH nonces (replays rejected as "Replayed request.", no backend call)', /Replayed request/.test(brief(ra).message || '') && /Replayed request/.test(brief(rb).message || '') && reachedA === 0 && reachedB === 0, { A: brief(ra), B: brief(rb), reachedA, reachedB });
  check('S5 each run executed once', [run5a, run5b].every((x) => mocks.runs[x].status === 'success' && mocks.runs[x].completions === 1), [mocks.runs[run5a], mocks.runs[run5b]]);
  evidence.S5 = { first: pair.map(brief), replayA: { ...brief(ra), new_start_calls: reachedA }, replayB: { ...brief(rb), new_start_calls: reachedB }, runA: snapshot(run5a), runB: snapshot(run5b) };

  finish(server, mocks, evidence);
}

function finish(server, mocks, evidence) {
  if (server) server.kill();
  mocks.close();
  console.log('\nEVIDENCE ' + JSON.stringify(evidence, null, 1));
  const failed = results.filter((x) => !x.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
  if (failed.length) { console.log('FAILED:\n - ' + failed.map((f) => f.name).join('\n - ')); process.exitCode = 1; }
  setTimeout(() => process.exit(), 1500);
}
main().catch((e) => { console.error(e); process.exit(1); });
