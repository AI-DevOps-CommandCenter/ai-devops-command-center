// Interop: the request workflow 06 sends to the playbook executor (executor
// mode) is verified by the executor's REAL Python verifier
// (infrastructure/playbooks/executor/executor/signing.py, standard library only).
// Needs python on PATH. The signing.py path can be overridden with
// EXECUTOR_SIGNING_PY (e.g. a copy taken from the feature/monitoring branch).
// Run: cd automation && npm run test:interop:executor
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { buildAll, WF } from '../scripts/build-workflows.mjs';

const SIGNING_PY = process.env.EXECUTOR_SIGNING_PY
  || fileURLToPath(new URL('../../infrastructure/playbooks/executor/executor/signing.py', import.meta.url));
const EXEC = 'interop-test-only-executor-secret-012345';
const RUN = '11111111-1111-4111-8111-111111111111';
const PY = process.platform === 'win32' ? 'python' : 'python3';

async function n8nExecutorRequest(action) {
  const wf = buildAll().find((x) => x.meta.id === WF.remediation.id).json;
  const code = wf.nodes.find((n) => n.name === 'Execute: ' + action).parameters.jsCode;
  const fn = new Function('$input', '$env', 'require', 'Buffer', `return (async function () {\n${code}\n})();`);
  const d = { execution_mode: 'executor', action_type: action, playbook_run_id: RUN, request_payload: { service_name: 'sample-app' } };
  const env = { EXECUTOR_URL: 'http://127.0.0.1:9095', EXECUTOR_SIGNING_SECRET: EXEC };
  return (await fn({ first: () => ({ json: d }) }, env, createRequire(import.meta.url), Buffer))[0].json.request;
}

// Runs signing.verify() twice on the same request: first must pass, second is a replay.
function pythonVerify(req, secret) {
  const script = [
    'import importlib.util, json, sys',
    'spec = importlib.util.spec_from_file_location("signing", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)',
    'req = json.loads(sys.stdin.read())',
    'h = {k.lower(): v for k, v in req["headers"].items()}',
    'store = m.NonceStore()',
    'a = m.verify(sys.argv[2], h, req["method"], req["path"], req["body"], store)',
    'b = m.verify(sys.argv[2], h, req["method"], req["path"], req["body"], store)',
    'print(json.dumps([[a.ok, a.status], [b.ok, b.status]]))',
  ].join('\n');
  const r = spawnSync(PY, ['-I', '-c', script, SIGNING_PY, secret], { input: JSON.stringify(req), encoding: 'utf8' });
  if (r.status !== 0) throw new Error('python failed: ' + (r.stderr || r.error));
  return JSON.parse(r.stdout);
}

test('executor signing.py accepts the request built by workflow 06 (and rejects a replay)', { skip: !existsSync(SIGNING_PY) && 'signing.py not found: ' + SIGNING_PY }, async () => {
  for (const action of ['restart', 'circuit_breaker']) {
    const req = await n8nExecutorRequest(action);
    assert.deepEqual(pythonVerify(req, EXEC), [[true, 200], [false, 409]], action);
  }
});

test('executor signing.py rejects a wrong secret and a tampered body', { skip: !existsSync(SIGNING_PY) && 'signing.py not found' }, async () => {
  const req = await n8nExecutorRequest('restart');
  assert.equal(pythonVerify(req, 'another-secret-another-secret-another-0')[0][1], 401);
  const tampered = { ...req, body: req.body.replace('sample-app', 'database') };
  assert.equal(pythonVerify(tampered, EXEC)[0][1], 401);
});
