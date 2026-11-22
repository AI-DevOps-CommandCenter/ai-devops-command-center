#!/usr/bin/env node
// Lists open incidents created from a sample-app alert (HighErrorRate), READ-ONLY.
//
//   node scripts/check-open-alert-incidents.mjs
//
// Why: create_incident_from_alert attaches a new alert to the incident with the
// same alert fingerprint while that incident is not resolved or closed (also
// when it is hidden with environment = 'test'). Then the next deploy-bad
// creates no new incident. Used by scripts/demo-start.sh.
//
// Logs in with TEST_USER_EMAIL / TEST_USER_PASSWORD from backend/.env and only
// reads public.incidents (Supabase REST, row level security applies).
// Prints no secrets.
//
// Exit codes: 0 no open alert incident, 3 open alert incident(s) found
// (one line each: id | status | environment | created_at | title),
// 2 could not check (the reason is printed).
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SERVICE = 'sample-app';

function loadEnv(file) {
  const env = {};
  if (!existsSync(file)) return env;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)$/);
    if (m) env[m[1]] = m[2].trim().replace(/^(["'])(.*)\1$/, '$2');
  }
  return env;
}

function cannotCheck(reason) {
  console.log(reason);
  process.exit(2);
}

const env = loadEnv(join(ROOT, 'backend', '.env'));
const { SUPABASE_URL: url, SUPABASE_PUBLISHABLE_KEY: key, TEST_USER_EMAIL: email, TEST_USER_PASSWORD: password } = env;
if (!url || !key || !email || !password) {
  cannotCheck('backend/.env needs SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, TEST_USER_EMAIL and TEST_USER_PASSWORD');
}

async function request(path, opts = {}) {
  try {
    const r = await fetch(url.replace(/\/$/, '') + path, { ...opts, signal: AbortSignal.timeout(10000) });
    return { status: r.status, json: await r.json().catch(() => undefined) };
  } catch (e) {
    return { status: 0, error: e.message };
  }
}

const login = await request('/auth/v1/token?grant_type=password', {
  method: 'POST',
  headers: { apikey: key, 'content-type': 'application/json' },
  body: JSON.stringify({ email, password }),
});
const token = login.json?.access_token;
if (!token) cannotCheck(`could not log in to Supabase as the test user (HTTP ${login.status || login.error})`);

const query = new URLSearchParams({
  select: 'id,title,status,environment,created_at',
  service_name: `eq.${SERVICE}`,
  alert_fingerprint: 'not.is.null',
  status: 'not.in.(resolved,closed)',
  order: 'created_at.asc',
});
const res = await request(`/rest/v1/incidents?${query}`, {
  headers: { apikey: key, authorization: `Bearer ${token}` },
});
if (res.status !== 200 || !Array.isArray(res.json)) {
  cannotCheck(`could not read incidents (HTTP ${res.status || res.error})`);
}

for (const i of res.json) {
  console.log([i.id, i.status, i.environment ?? '-', i.created_at, i.title].join(' | '));
}
process.exit(res.json.length ? 3 : 0);
