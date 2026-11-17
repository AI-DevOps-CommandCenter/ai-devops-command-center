#!/usr/bin/env node
// Prepares a fresh clone for local use. Creates the git-ignored .env files and
// the local-only secrets that every developer generates for themselves.
//
//   node scripts/setup-local.mjs           create what is missing
//   node scripts/setup-local.mjs --check   only report, change nothing
//
// What it does (never overwrites a value that is already set, never prints a secret):
//   1. backend/.env, automation/.env, monitoring/.env: copied from .env.example if missing.
//      A new automation/.env also gets the tested monitoring values from
//      monitoring/n8n-integration.env.
//   2. Random secrets, the same value in every file that needs it:
//        MACHINE_SIGNING_SECRET   backend/.env + automation/.env   (HMAC, n8n <-> backend)
//        EXECUTOR_SIGNING_SECRET  monitoring/.env + automation/.env (HMAC, n8n -> executor)
//        N8N_ENCRYPTION_KEY       automation/.env                  (encrypts n8n credentials)
//   3. monitoring/alertmanager/secrets/n8n-token: the token Alertmanager sends to n8n.
//   4. Lists the values you still have to fill in by hand (see docs/SETUP.md).
import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, copyFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const CHECK = process.argv.includes('--check');
const rel = (p) => p.slice(ROOT.length + 1).replaceAll('\\', '/');

const FILES = {
  backend: join(ROOT, 'backend', '.env'),
  automation: join(ROOT, 'automation', '.env'),
  monitoring: join(ROOT, 'monitoring', '.env'),
};
const TOKEN_FILE = join(ROOT, 'monitoring', 'alertmanager', 'secrets', 'n8n-token');
const N8N_INTEGRATION = join(ROOT, 'monitoring', 'n8n-integration.env');

const SHARED_SECRETS = [
  { key: 'MACHINE_SIGNING_SECRET', files: ['backend', 'automation'] },
  { key: 'EXECUTOR_SIGNING_SECRET', files: ['monitoring', 'automation'] },
  { key: 'N8N_ENCRYPTION_KEY', files: ['automation'] },
];

// Values that must come from a teammate or from your own accounts.
const MANUAL = [
  { file: 'backend', key: 'SUPABASE_URL', from: 'shared privately (team lead)' },
  { file: 'backend', key: 'SUPABASE_PUBLISHABLE_KEY', from: 'shared privately (team lead)' },
  { file: 'backend', key: 'AUTOMATION_EMAIL', from: 'shared privately (team lead)' },
  { file: 'backend', key: 'AUTOMATION_PASSWORD', from: 'shared privately (team lead)' },
  { file: 'backend', key: 'GITHUB_TOKEN', from: 'your own read-only GitHub token (optional: CI/CD screens)', optional: true },
  { file: 'backend', key: 'TEST_USER_PASSWORD', from: 'shared privately (optional: check-project.mjs)', optional: true },
  { file: 'backend', key: 'TEST_REQUESTER_PASSWORD', from: 'shared privately (optional: check-project.mjs)', optional: true },
  { file: 'automation', key: 'GROQ_MODEL', from: 'model name, see docs/SETUP.md' },
];

const newSecret = () => randomBytes(48).toString('base64url');

// Empty values and the placeholders used in the .env.example files count as "not set".
const isUnset = (v) => v === undefined || v.trim() === '' || /^(change-me|your[_-])/i.test(v.trim()) || v.includes('your-project-ref');

function parse(text) {
  const out = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=(.*)$/);
    if (m) out[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
  }
  return out;
}

const read = (file) => (existsSync(file) ? readFileSync(file, 'utf8') : '');

// Set KEY=value in an env file: replace the active line, else a commented "# KEY=" line, else append.
function setValue(file, key, value) {
  let text = read(file);
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  const active = new RegExp(`^[ \\t]*${key}[ \\t]*=.*$`, 'm');
  const commented = new RegExp(`^[ \\t]*#[ \\t]*${key}[ \\t]*=.*$`, 'm');
  const line = `${key}=${value}`;
  if (active.test(text)) text = text.replace(active, () => line);
  else if (commented.test(text)) text = text.replace(commented, () => line);
  else text = `${text}${text === '' || text.endsWith('\n') ? '' : eol}${line}${eol}`;
  writeFileSync(file, text);
}

let problems = 0;
const todo = [];
const log = (s) => console.log(s);

// 1. .env files ----------------------------------------------------------------------
log(CHECK ? '== Checking local setup (no changes)' : '== Local setup');
for (const [name, file] of Object.entries(FILES)) {
  if (existsSync(file)) { log(`  ok      ${rel(file)} exists`); continue; }
  if (CHECK) { log(`  MISSING ${rel(file)}`); problems++; continue; }
  copyFileSync(`${file}.example`, file);
  log(`  created ${rel(file)} from ${rel(file)}.example`);
  if (name === 'automation') {
    const integration = parse(read(N8N_INTEGRATION));
    for (const [k, v] of Object.entries(integration)) setValue(file, k, v);
    log(`          + monitoring values from ${rel(N8N_INTEGRATION)}`);
  }
}

// 2. Shared secrets --------------------------------------------------------------------
for (const { key, files } of SHARED_SECRETS) {
  const present = files.filter((f) => existsSync(FILES[f]));
  const values = present.map((f) => parse(read(FILES[f]))[key]);
  const set = [...new Set(values.filter((v) => !isUnset(v)))];
  const where = files.map((f) => rel(FILES[f])).join(' + ');

  if (set.length > 1) {
    log(`  MISMATCH ${key} differs between ${where} - make them equal by hand`);
    problems++;
    continue;
  }
  const missingIn = present.filter((f, i) => isUnset(values[i]));
  if (missingIn.length === 0 && present.length === files.length) { log(`  ok      ${key} (${where})`); continue; }
  if (CHECK) { log(`  MISSING ${key} in ${missingIn.map((f) => rel(FILES[f])).join(', ')}`); problems++; continue; }

  const value = set[0] ?? newSecret();
  for (const f of missingIn) setValue(FILES[f], key, value);
  log(`  ${set.length ? 'copied ' : 'created'} ${key} -> ${missingIn.map((f) => rel(FILES[f])).join(', ')}`);
  if (key === 'N8N_ENCRYPTION_KEY') {
    log('          (an n8n data volume created with an older key cannot read its credentials - see docs/SETUP.md)');
  }
}

// 3. Alertmanager -> n8n token ---------------------------------------------------------------
if (existsSync(TOKEN_FILE) && readFileSync(TOKEN_FILE, 'utf8').trim() !== '') {
  log(`  ok      ${rel(TOKEN_FILE)}`);
} else if (CHECK) {
  log(`  MISSING ${rel(TOKEN_FILE)}`);
  problems++;
} else {
  mkdirSync(dirname(TOKEN_FILE), { recursive: true });
  writeFileSync(TOKEN_FILE, newSecret());
  log(`  created ${rel(TOKEN_FILE)}`);
  todo.push('n8n credential "Alertmanager Webhook Token": Value = Bearer <content of monitoring/alertmanager/secrets/n8n-token>');
}

// 4. Values to fill in by hand ------------------------------------------------------------------
for (const { file, key, from, optional } of MANUAL) {
  if (!existsSync(FILES[file])) continue;
  if (isUnset(parse(read(FILES[file]))[key])) {
    todo.push(`${rel(FILES[file])}: ${key}  <- ${from}`);
    if (!optional && CHECK) problems++;
  }
}

if (todo.length) {
  log('\n== Still to do by hand');
  for (const t of todo) log(`  - ${t}`);
}
log(problems ? `\n${problems} problem(s) found.` : '\nLocal secrets are in place. Next steps: docs/SETUP.md');
process.exit(problems ? 1 : 0);
