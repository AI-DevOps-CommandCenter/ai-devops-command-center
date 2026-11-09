// I-6: every environment variable the Code nodes read must be documented in
// automation/.env.example and passed into the n8n container by
// automation/docker-compose.yml, with the same default as the code.
// Static checks only (no Docker, no n8n). Run: cd automation && node --test tests/env-config.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => readFileSync(join(ROOT, p), 'utf8').replace(/\r\n?/g, '\n');
const TIMEOUTS = ['LOKI_TIMEOUT_MS', 'PROMETHEUS_TIMEOUT_MS', 'GITHUB_TIMEOUT_MS'];

// All Code-node sources (shared helpers included).
const sources = [];
for (const dir of ['src/lib', ...readdirSync(join(ROOT, 'src/nodes')).map((d) => 'src/nodes/' + d)]) {
  for (const f of readdirSync(join(ROOT, dir)).filter((x) => x.endsWith('.js'))) sources.push({ file: dir + '/' + f, text: read(dir + '/' + f) });
}

// envInt(env, 'NAME', default, min, max) calls -> { NAME: [{ file, def, min, max }] }
const envIntCalls = {};
for (const { file, text } of sources) {
  for (const m of text.matchAll(/envInt\(env, '([A-Z0-9_]+)', (\d+), (\d+), (\d+)\)/g)) {
    (envIntCalls[m[1]] = envIntCalls[m[1]] || []).push({ file, def: Number(m[2]), min: Number(m[3]), max: Number(m[4]) });
  }
}

// Every variable name the code reads: env.NAME, envInt/envNumber(env, 'NAME'), and the PROM_* names used through env[m.env].
const usedVars = new Set();
for (const { text } of sources) {
  for (const m of text.matchAll(/\benv\.([A-Z][A-Z0-9_]+)/g)) usedVars.add(m[1]);
  for (const m of text.matchAll(/env(?:Int|Number)\(env, '([A-Z0-9_]+)'/g)) usedVars.add(m[1]);
  for (const m of text.matchAll(/'(PROM_(?:QUERY|THRESHOLD)_[A-Z0-9_]+)'/g)) usedVars.add(m[1]);
}

// automation/.env.example: KEY=VALUE lines.
const example = Object.fromEntries(read('.env.example').split('\n').map((l) => l.match(/^([A-Z][A-Z0-9_]*)=(.*)$/)).filter(Boolean).map((m) => [m[1], m[2]]));

// docker-compose.yml: the environment block of services.n8n.
const compose = read('docker-compose.yml');
const n8nBlock = compose.match(/\n {2}n8n:\n([\s\S]*?)(?=\n {2}[a-z]|\nvolumes:)/);
assert.ok(n8nBlock, 'services.n8n not found in docker-compose.yml');
const envBlock = n8nBlock[1].match(/\n {4}environment:\n([\s\S]*?)(?=\n {4}[a-z_]+:|$)/);
assert.ok(envBlock, 'services.n8n.environment not found');
const composeEnv = {};
for (const line of envBlock[1].split('\n')) {
  const m = line.match(/^ {6}([A-Z][A-Z0-9_]*): "(.*)"$/);
  if (m) composeEnv[m[1]] = m[2];
}
const composeDefault = (name) => {
  const m = String(composeEnv[name] || '').match(/^\$\{([A-Z0-9_]+):-(.*)\}$/);
  return m && m[1] === name ? m[2] : undefined;
};

test('I-6: the three timeout variables are read by the code with one consistent default', () => {
  assert.deepEqual(Object.keys(envIntCalls).filter((k) => TIMEOUTS.includes(k)).sort(), [...TIMEOUTS].sort());
  for (const name of TIMEOUTS) {
    const calls = envIntCalls[name];
    assert.equal(new Set(calls.map((c) => c.def + '/' + c.min + '/' + c.max)).size, 1, name + ' has different defaults in ' + calls.map((c) => c.file).join(', '));
  }
  // Expected defaults (unchanged by I-6).
  assert.equal(envIntCalls.LOKI_TIMEOUT_MS[0].def, 15000);
  assert.equal(envIntCalls.PROMETHEUS_TIMEOUT_MS[0].def, 10000);
  assert.equal(envIntCalls.GITHUB_TIMEOUT_MS[0].def, 15000);
  assert.deepEqual(envIntCalls.PROMETHEUS_TIMEOUT_MS.map((c) => c.file).sort(), ['src/nodes/03-metrics-analysis/build-queries.js', 'src/nodes/07-recovery-check/plan.js']);
});

test('I-6: the timeout variables are documented in .env.example with the code defaults', () => {
  for (const name of TIMEOUTS) {
    assert.ok(name in example, name + ' missing from .env.example');
    assert.match(example[name], /^\d+$/, name + ' must be a plain number of milliseconds');
    const { def, min, max } = envIntCalls[name][0];
    assert.equal(Number(example[name]), def, name + ' example value must equal the code default');
    assert.ok(def >= min && def <= max);
  }
});

test('I-6: the timeout variables are passed into the n8n container with the code defaults', () => {
  for (const name of TIMEOUTS) {
    assert.ok(name in composeEnv, name + ' missing from services.n8n.environment');
    assert.equal(composeDefault(name), String(envIntCalls[name][0].def), name + ' must be "${' + name + ':-<code default>}"');
  }
});

test('I-6: every variable read by the Code nodes is documented and passed into the container', () => {
  const missingExample = [...usedVars].filter((v) => !(v in example)).sort();
  const missingCompose = [...usedVars].filter((v) => !(v in composeEnv)).sort();
  assert.deepEqual(missingExample, [], 'not in .env.example');
  assert.deepEqual(missingCompose, [], 'not in docker-compose.yml services.n8n.environment');
  // Every envInt default in the code matches the compose default (where compose sets one).
  for (const [name, calls] of Object.entries(envIntCalls)) {
    const d = composeDefault(name);
    if (d !== undefined && d !== '') assert.equal(Number(d), calls[0].def, name + ': compose default differs from the code default');
  }
});

test('I-6: no secrets in .env.example or docker-compose.yml', () => {
  const secretPatterns = [/gsk_[A-Za-z0-9]{10,}/, /gh[pousr]_[A-Za-z0-9]{20,}/, /github_pat_/, /eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/, /hooks\.slack\.com\/services\/[A-Z0-9]/, /discord(?:app)?\.com\/api\/webhooks\/\d/, /Bearer [A-Za-z0-9._-]{10,}/];
  for (const [file, text] of [['.env.example', read('.env.example')], ['docker-compose.yml', compose]]) {
    for (const re of secretPatterns) assert.doesNotMatch(text, re, file + ' contains a secret-like value');
  }
  // Secret settings have no default in compose: they come only from the operator's .env.
  for (const name of ['MACHINE_SIGNING_SECRET', 'ERROR_NOTIFY_WEBHOOK_URL']) assert.equal(composeDefault(name), '', name);
  assert.match(composeEnv.N8N_ENCRYPTION_KEY, /^\$\{N8N_ENCRYPTION_KEY:\?/, 'encryption key must be required, not defaulted');
  assert.equal(example.ERROR_NOTIFY_WEBHOOK_URL, '');
});
