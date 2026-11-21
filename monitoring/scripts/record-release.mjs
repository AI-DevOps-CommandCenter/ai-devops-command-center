#!/usr/bin/env node
// Records a local release in the deployments table, so workflow 04 can link
// an incident to the release just before it (deployment correlation).
//
//   node scripts/record-release.mjs <service_name> <version>
//
// Sends POST /api/machine/deployments, signed like the n8n requests
// (backend/src/middleware/machine-auth.ts). Settings:
//   RELEASE_BACKEND_URL     backend URL (default http://127.0.0.1:3000)
//   MACHINE_SIGNING_SECRET  from the environment, else from automation/.env
// The secret is never printed. Exit code 1 when the release was not recorded;
// release.sh only warns then.
import { createHmac, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const PATH = '/api/machine/deployments';

export function signRequest(secret, method, path, body, now = Date.now()) {
  const timestamp = Math.floor(now / 1000);
  const nonce = randomBytes(24).toString('base64url');
  const canonical = [String(timestamp), nonce, method.toUpperCase(), path, body].join('.');
  return {
    'X-DC-Timestamp': String(timestamp),
    'X-DC-Nonce': nonce,
    'X-DC-Signature': 'sha256=' + createHmac('sha256', secret).update(canonical, 'utf8').digest('hex'),
  };
}

// Reads KEY=value from a .env file (no export, no interpolation).
export function readEnvValue(file, key) {
  let text;
  try { text = readFileSync(file, 'utf8'); } catch { return undefined; }
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && m[1] === key) return m[2].replace(/^(['"])(.*)\1$/, '$2');
  }
  return undefined;
}

export function buildRelease(serviceName, version, secret, now) {
  const body = JSON.stringify({ service_name: serviceName, version, status: 'success', provider: 'local' });
  return { body, headers: { 'Content-Type': 'application/json', ...signRequest(secret, 'POST', PATH, body, now) } };
}

async function main() {
  const [serviceName, version] = process.argv.slice(2);
  if (!serviceName || !version) {
    console.error('usage: node scripts/record-release.mjs <service_name> <version>');
    return 2;
  }
  const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
  const secret = process.env.MACHINE_SIGNING_SECRET || readEnvValue(join(root, 'automation', '.env'), 'MACHINE_SIGNING_SECRET');
  if (!secret || secret.length < 32) {
    console.error('release not recorded: MACHINE_SIGNING_SECRET is not set (environment or automation/.env).');
    return 1;
  }
  const base = String(process.env.RELEASE_BACKEND_URL || 'http://127.0.0.1:3000').replace(/\/+$/, '');
  const { body, headers } = buildRelease(serviceName, version, secret);
  try {
    const res = await fetch(base + PATH, { method: 'POST', headers, body, signal: AbortSignal.timeout(10000) });
    if (res.status !== 201) {
      const text = (await res.text()).slice(0, 200);
      console.error(`release not recorded: backend answered ${res.status} ${text}`);
      return 1;
    }
    console.log(`recorded release ${serviceName} ${version}`);
    return 0;
  } catch (e) {
    console.error(`release not recorded: backend not reachable at ${base} (${e.name})`);
    return 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await main();
}
