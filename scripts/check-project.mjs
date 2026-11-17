#!/usr/bin/env node
// Checks that every part of the DevOps Command Center is running and answering.
// Read-only: it never creates incidents, approvals or runs.
//
//   node scripts/check-project.mjs            all checks
//   node scripts/check-project.mjs --quick    skip the monitoring query checks (check_stack.py)
//
// The logged-in API checks use TEST_USER_* / TEST_REQUESTER_* from backend/.env
// (git-ignored). Missing values only skip those checks.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const QUICK = process.argv.includes('--quick');
const BACKEND = process.env.BACKEND_URL ?? 'http://localhost:3000';
const WEB = process.env.WEB_URL ?? 'http://127.0.0.1:8080';

const results = [];
const pass = (name, detail = '') => { results.push(true); console.log(`  PASS  ${name}${detail ? `  (${detail})` : ''}`); };
const fail = (name, detail = '') => { results.push(false); console.log(`  FAIL  ${name}${detail ? `  -> ${detail}` : ''}`); };
const skip = (name, why) => console.log(`  SKIP  ${name}  (${why})`);
const section = (t) => console.log(`\n== ${t}`);

function loadEnv(file) {
  const env = {};
  if (!existsSync(file)) return env;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return env;
}

async function http(url, opts = {}) {
  try {
    const r = await fetch(url, { ...opts, signal: AbortSignal.timeout(8000) });
    const text = await r.text();
    let json; try { json = JSON.parse(text); } catch { json = undefined; }
    return { status: r.status, text, json };
  } catch (e) {
    return { status: 0, text: String(e.cause?.code ?? e.message) };
  }
}

async function expectStatus(name, url, want, opts) {
  const r = await http(url, opts);
  const ok = Array.isArray(want) ? want.includes(r.status) : r.status === want;
  ok ? pass(name, `HTTP ${r.status}`) : fail(name, r.status ? `HTTP ${r.status}, expected ${want}` : `not reachable (${r.text})`);
  return r;
}

function sh(cmd, args) {
  try { return execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }); } catch { return null; }
}

// 1. Docker containers ---------------------------------------------------------
section('1. Docker containers');
const ps = sh('docker', ['ps', '--format', '{{.Names}}|{{.Status}}']);
if (ps === null) {
  fail('Docker is running', 'docker not reachable - start Docker Desktop');
} else {
  const running = Object.fromEntries(ps.trim().split('\n').filter(Boolean).map((l) => l.split('|')));
  for (const c of ['n8n', 'dc-sample-app', 'dc-monitoring-prometheus-1', 'dc-monitoring-alertmanager-1',
    'dc-monitoring-loki-1', 'dc-monitoring-promtail-1', 'dc-monitoring-executor-1', 'dc-monitoring-loadgen-1']) {
    const st = running[c];
    st && st.startsWith('Up') && !st.includes('unhealthy') ? pass(c, st) : fail(c, st ?? 'not running');
  }
}

// 2. Monitoring stack ------------------------------------------------------------
section('2. Monitoring (Prometheus, Alertmanager, Loki, executor)');
await expectStatus('Prometheus ready', 'http://127.0.0.1:9090/-/ready', 200);
const targets = await http('http://127.0.0.1:9090/api/v1/targets');
if (targets.json) {
  const active = targets.json.data.activeTargets;
  const down = active.filter((t) => t.health !== 'up').map((t) => t.labels.job);
  down.length ? fail('Prometheus scrape targets up', `down: ${down.join(', ')}`) : pass('Prometheus scrape targets up', `${active.length} up`);
}
const rules = await http('http://127.0.0.1:9090/api/v1/rules');
if (rules.json) {
  const names = rules.json.data.groups.flatMap((g) => g.rules.map((r) => r.name));
  names.includes('HighErrorRate') ? pass('Alert rules loaded', `${names.length} rules`) : fail('Alert rules loaded', 'HighErrorRate missing');
}
const alerts = await http('http://127.0.0.1:9090/api/v1/alerts');
if (alerts.json) {
  const firing = alerts.json.data.alerts.filter((a) => a.state === 'firing').map((a) => a.labels.alertname);
  console.log(`  INFO  alerts firing now: ${firing.length ? firing.join(', ') : 'none'}`);
}
await expectStatus('Alertmanager ready', 'http://127.0.0.1:9093/-/ready', 200);
// Loki's /ready can return 503 for a short time while its ring settles: retry.
for (let i = 0; ; i++) {
  const r = await http('http://127.0.0.1:3100/ready');
  if (r.status === 200) { pass('Loki ready', i ? `after ${i} retries` : 'HTTP 200'); break; }
  if (i === 5) { fail('Loki ready', `HTTP ${r.status} after 6 tries - docker restart dc-monitoring-loki-1`); break; }
  await new Promise((res) => setTimeout(res, 3000));
}
await expectStatus('Executor rejects unsigned requests', 'http://127.0.0.1:9095/v1/execute', 401,
  { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' });
const fault = sh('docker', ['exec', 'dc-sample-app', 'python', '-c',
  "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000/admin/fault',timeout=5).read().decode())"]);
if (fault) {
  const f = JSON.parse(fault);
  console.log(`  INFO  sample-app fault=${f.mode} rate=${f.rate} breaker_open=${f.breaker_open}`);
  f.mode === 'off' && !f.breaker_open ? pass('sample-app in normal state') : fail('sample-app in normal state', 'fault or breaker still on (scripts/fault.sh off / breaker closed)');
}
if (!QUICK) {
  const py = sh('python', [join(ROOT, 'monitoring', 'scripts', 'check_stack.py')]);
  if (py === null) fail('monitoring/scripts/check_stack.py', 'failed - run it directly to see why');
  else { const last = py.trim().split('\n').pop(); /FAIL/.test(py) ? fail('check_stack.py', last) : pass('check_stack.py (queries used by n8n)', last); }
}

// 3. n8n -----------------------------------------------------------------------
section('3. n8n automation');
await expectStatus('n8n up', 'http://127.0.0.1:5678/healthz', 200);
await expectStatus('Workflow 06 webhook rejects unsigned requests', 'http://127.0.0.1:5678/webhook/remediation', 401,
  { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' });
const wf = sh('docker', ['exec', 'n8n', 'n8n', 'list:workflow', '--active=true']);
if (wf !== null) {
  const active = wf.split('\n').filter((l) => /\|/.test(l)).map((l) => l.split('|')[1].trim());
  const need = ['01', '02', '03', '04', '05', '06', '07', '08'];
  const missing = need.filter((n) => !active.some((a) => a.startsWith(n)));
  missing.length ? fail('Workflows 01-08 active', `inactive: ${missing.join(', ')}`) : pass('Workflows 01-08 active', `${active.length} active`);
}
const log = sh('docker', ['exec', 'n8n', 'sh', '-c', 'grep -h "n8n.workflow.failed" /home/node/.n8n/n8nEventLog.log | tail -3']);
if (log !== null) {
  const recent = log.trim().split('\n').filter(Boolean).map((l) => { try { const j = JSON.parse(l); return `${j.ts.slice(0, 19)} ${j.payload.workflowName}`; } catch { return null; } }).filter(Boolean);
  console.log(`  INFO  last failed executions: ${recent.length ? recent.join('; ') : 'none in current log'}`);
}

// 4. Backend + database ---------------------------------------------------------
section('4. Backend API + Supabase');
await expectStatus('Backend up', `${BACKEND}/`, 200);
await expectStatus('Backend rejects requests without login', `${BACKEND}/api/incidents`, 401);
const env = loadEnv(join(ROOT, 'backend', '.env'));
async function login(email, password) {
  const r = await http(`${env.SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST', headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  return r.json?.access_token;
}
const users = [
  ['approver', env.TEST_USER_EMAIL ?? 'demo.admin@demo.local', env.TEST_USER_PASSWORD],
  ['requester', env.TEST_REQUESTER_EMAIL, env.TEST_REQUESTER_PASSWORD],
];
for (const [role, email, password] of users) {
  if (!env.SUPABASE_URL || !email || !password) { skip(`Login as ${role}`, 'credentials not in backend/.env'); continue; }
  const token = await login(email, password);
  if (!token) { fail(`Login as ${role}`, email); continue; }
  const auth = { headers: { authorization: `Bearer ${token}` } };
  const me = await http(`${BACKEND}/api/me`, auth);
  me.status === 200 ? pass(`Login as ${role}`, email) : fail(`Login as ${role}`, `/api/me HTTP ${me.status}`);
  if (role !== 'approver') continue;
  for (const [name, path] of [
    ['Dashboard summary', '/api/dashboard/summary'],
    ['Incidents list', '/api/incidents'],
    ['Pending approvals', '/api/approvals?status=pending'],
    ['Playbook runs', '/api/playbook-runs'],
    ['Postmortems', '/api/postmortems'],
    ['Notifications', '/api/notifications'],
    ['Playbooks (admin)', '/api/admin/playbooks'],
  ]) {
    const r = await http(`${BACKEND}${path}`, auth);
    const n = Array.isArray(r.json?.data) ? `${r.json.data.length} rows` : '';
    r.status === 200 ? pass(name, n) : fail(name, `HTTP ${r.status} ${r.json?.message ?? ''}`);
  }
  const inc = await http(`${BACKEND}/api/incidents`, auth);
  const open = (inc.json?.data ?? []).filter((i) => !['resolved', 'closed'].includes(i.status));
  console.log(`  INFO  open incidents: ${open.length ? open.map((i) => `${i.id.slice(0, 8)} ${i.status} "${i.title}"`).join('; ') : 'none'}`);
}

// 5. Mobile web app -------------------------------------------------------------
section('5. Mobile app (Flutter web build)');
const web = await expectStatus('Web app served', `${WEB}/`, 200);
if (web.status === 200 && !/flutter/i.test(web.text)) fail('Web app is the Flutter build', 'page does not look like Flutter');

// Summary -------------------------------------------------------------------------
const failed = results.filter((r) => !r).length;
console.log(`\n${failed === 0 ? 'ALL GOOD' : 'PROBLEMS FOUND'}: ${results.length - failed}/${results.length} checks passed.`);
process.exit(failed === 0 ? 0 : 1);
