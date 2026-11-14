// Mock external services for the n8n integration tests (no real Groq, Loki,
// Prometheus, GitHub or backend is contacted).
//   port A (services): /groq/openai/v1/*, /loki/*, /prom/*, /gh/*, /__scenario, /__calls
//   port B (backend):  /api/machine/*  (HMAC verified like backend/src/middleware/machine-auth.ts)
// The scenario (which answer each service gives) is set by the test runner.
import http from 'node:http';
import https from 'node:https';
import { createHmac, timingSafeEqual, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const DATA = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'test-data');
const logs = JSON.parse(readFileSync(join(DATA, 'sample-logs.json'), 'utf8'));
const metrics = JSON.parse(readFileSync(join(DATA, 'sample-metrics.json'), 'utf8'));
const deploys = JSON.parse(readFileSync(join(DATA, 'sample-deployment.json'), 'utf8'));
const INCIDENT_AT = Date.parse(metrics.incident_at);

// HTTPS receiver for the error notifications of workflow 09 (stands in for a
// Slack/Discord incoming webhook). Records every POST body.
export function startNotificationReceiver({ port, key, cert }) {
  const received = [];
  const server = https.createServer({ key, cert }, (req, res) => {
    let b = '';
    req.on('data', (c) => (b += c));
    req.on('end', () => {
      let body; try { body = JSON.parse(b); } catch { body = b; }
      received.push({ path: req.url, body, raw: b });
      res.writeHead(200, { 'content-type': 'text/plain' });
      res.end('ok');
    });
  });
  server.listen(port, '127.0.0.1');
  return { received, close: () => server.close() };
}

export function startMocks({ servicesPort, backendPort, secret, backendTimeoutMs = 1500 }) {
  // complete: queue of answers for the next /complete calls ('ok' when empty):
  //   'ok' | <HTTP status> | 'timeout' (no answer in time, nothing changed) |
  //   'timeout_commit' (the run IS completed, the answer comes too late) | 'reset' (connection dropped)
  // start: 'ok' | 'timeout'.  recovery_store: 'ok' | 'not_found' | <HTTP status>.
  const scenario = { groq: 'ok', loki: 'errors', prom: 'abnormal', recovery: 'recovered', github: 'recent', complete: [], start: 'ok', recovery_store: 'ok' };
  const late = backendTimeoutMs * 2;
  const calls = [];
  const nonces = new Set();
  const recoveryChecks = [];
  const runs = {
    '11111111-1111-4111-8111-111111111111': { status: 'approved', action_type: 'restart', incident_id: '22222222-2222-4222-8222-222222222222' },
    '33333333-3333-4333-8333-333333333333': { status: 'pending', action_type: 'rollback', incident_id: '22222222-2222-4222-8222-222222222222' },
    '55555555-5555-4555-8555-555555555555': { status: 'approved', action_type: 'restart', incident_id: '22222222-2222-4222-8222-222222222222' },
  };

  // A late answer (timeout scenarios) may arrive after the client gave up.
  const send = (res, status, body, delay = 0) => setTimeout(() => {
    if (res.destroyed || res.writableEnded) return;
    try {
      res.writeHead(status, { 'content-type': 'application/json' });
      res.end(typeof body === 'string' ? body : JSON.stringify(body));
    } catch { /* client already disconnected */ }
  }, delay);
  const readBody = (req) => new Promise((r) => { let b = ''; req.on('data', (c) => (b += c)); req.on('end', () => r(b)); });
  const vector = (v) => ({ status: 'success', data: { resultType: 'vector', result: v === null ? [] : [{ metric: {}, value: [Date.now() / 1000, String(v)] }] } });

  const services = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://x');
    const body = await readBody(req);
    calls.push({ port: 'services', method: req.method, path: url.pathname, auth: req.headers.authorization ? 'present' : 'none' });

    if (url.pathname === '/__scenario') { Object.assign(scenario, JSON.parse(body || '{}')); return send(res, 200, scenario); }
    if (url.pathname === '/__calls') { const out = calls.splice(0); return send(res, 200, out); }

    if (url.pathname === '/groq/openai/v1/chat/completions') {
      if (req.headers.authorization !== 'Bearer test-groq-key' || scenario.groq === 'auth') return send(res, 401, { error: { message: 'Invalid API Key' } });
      if (scenario.groq === 'rate_limited') return send(res, 429, { error: { message: 'Rate limit reached' } });
      if (scenario.groq === 'slow') return send(res, 200, {}, 6000);
      if (scenario.groq === 'bad_model') return send(res, 404, { error: { message: 'The model does not exist' } });
      const reqBody = JSON.parse(body);
      const system = reqBody.messages[0].content;
      let content;
      if (scenario.groq === 'garbage') content = 'I think the root cause is probably the database.';
      else if (scenario.groq === 'bad_action') content = JSON.stringify({ summary: 's', root_cause: 'r', severity: 'high', confidence: 0.7, confirmed_findings: [], possible_causes: [], evidence: [], recommended_action: 'rm -rf /', recommendations: [] });
      else if (/connectivity test/.test(system)) content = JSON.stringify({ status: 'ok', service: 'groq' });
      else if (/root cause analysis assistant/.test(system)) content = JSON.stringify({ summary: 'checkout-api 5xx spike after a deployment', root_cause: 'NullPointerException in PaymentService.charge introduced shortly before the incident (possible: deploy 501).', severity: 'critical', confidence: 0.72, confirmed_findings: ['error_rate 0.35 vs baseline 0.002', 'Repeated NullPointerException in PaymentService.charge'], possible_causes: ['Deployment 501 "Deploy to production" 15 min before the incident'], evidence: ['metrics: error_rate 175x baseline', 'logs: NullPointerException x4', 'github: run 501 at 09:45'], recommended_action: 'rollback', recommendations: ['Add a null check test for PaymentService.charge'] });
      else if (/postmortems/.test(system)) content = JSON.stringify({ title: 'checkout-api error spike', summary: 'Error rate rose to 35%.', timeline: [{ time: '2026-11-08T10:00:00Z', event: 'Alert fired' }], root_cause: 'Unknown – not recorded', impact: 'Checkout failures', evidence: ['recovery: up=1, error_rate 0.003'], remediation: 'Restart (simulated: no real system was changed)', recovery_result: 'Recovered', lessons_learned: ['Alert earlier'], preventive_actions: ['Add canary deploys'] });
      else content = '{}';
      return send(res, 200, { id: 'chatcmpl-test', model: reqBody.model, choices: [{ index: 0, message: { role: 'assistant', content } }], usage: { total_tokens: 42 } });
    }

    if (url.pathname === '/loki/loki/api/v1/query_range') {
      if (scenario.loki === 'down') return send(res, 503, 'service unavailable');
      if (scenario.loki === 'bad_query') return send(res, 400, 'parse error at line 1, col 2: syntax error');
      if (scenario.loki === 'empty') return send(res, 200, { status: 'success', data: { resultType: 'streams', result: [] } });
      return send(res, 200, logs);
    }

    if (url.pathname === '/prom/api/v1/query') {
      const q = url.searchParams.get('query') || '';
      const t = Date.parse(url.searchParams.get('time') || '');
      if (scenario.prom === 'down') return send(res, 503, 'unavailable');
      if (/\bup\{/.test(q)) return send(res, 200, vector(scenario.recovery === 'unavailable' ? null : 1));
      if (/errrate/.test(q) && t > INCIDENT_AT + 3600000) {
        if (scenario.recovery === 'unavailable') return send(res, 200, vector(null));
        // Recovery checks run "now" (long after the sample incident).
        return send(res, 200, vector(scenario.recovery === 'recovered' ? 0.003 : 0.4));
      }
      if (scenario.prom === 'missing') return send(res, 200, vector(null));
      const set = metrics[scenario.prom] || metrics.abnormal;
      const key = Object.keys(set).find((k) => q.includes(k));
      if (!key) return send(res, 200, vector(null));
      return send(res, 200, vector(t >= INCIDENT_AT ? set[key].incident : set[key].baseline));
    }

    if (url.pathname.startsWith('/gh/repos/acme/demo/')) {
      if (req.headers.authorization !== 'Bearer test-gh-token' || scenario.github === 'auth') return send(res, 401, { message: 'Bad credentials' });
      const none = scenario.github === 'none';
      if (url.pathname.endsWith('/commits')) return send(res, 200, none ? [] : deploys.commits);
      if (url.pathname.endsWith('/actions/runs')) return send(res, 200, none ? { total_count: 0, workflow_runs: [] } : deploys.workflow_runs);
    }
    return send(res, 404, { message: 'mock: not found ' + url.pathname });
  });

  const backend = http.createServer(async (req, res) => {
    const raw = await readBody(req);
    const h = req.headers;
    const call = { port: 'backend', method: req.method, path: req.url };
    calls.push(call);
    if (!req.url.startsWith('/api/machine/')) return send(res, 404, { success: false, message: 'Not found' });
    const ts = Number(h['x-dc-timestamp']);
    const expected = 'sha256=' + createHmac('sha256', secret).update([String(ts), h['x-dc-nonce'], req.method, req.url, raw].join('.'), 'utf8').digest('hex');
    const given = String(h['x-dc-signature'] || '');
    if (given.length !== expected.length || !timingSafeEqual(Buffer.from(given), Buffer.from(expected))) { call.auth = 'bad-signature'; return send(res, 401, { success: false, message: 'Invalid request signature.' }); }
    if (Math.abs(Date.now() / 1000 - ts) > 300) return send(res, 401, { success: false, message: 'Signed request is outside the 5 minute window.' });
    call.nonce = h['x-dc-nonce'];
    if (nonces.has(h['x-dc-nonce'])) return send(res, 409, { success: false, message: 'Replayed request.' });
    nonces.add(h['x-dc-nonce']);
    call.auth = 'ok';
    call.body = raw ? JSON.parse(raw) : null;

    const m = req.url.match(/^\/api\/machine\/playbook-runs\/([0-9a-f-]+)\/(start|complete)$/);
    if (m) {
      const run = runs[m[1]];
      if (!run) return send(res, 404, { success: false, message: 'Playbook run not found.' });
      if (m[2] === 'start') {
        if (scenario.start === 'timeout') { call.answer = 'timeout'; return send(res, 500, { success: false, message: 'too late' }, late); }
        if (run.status !== 'approved') return send(res, 409, { success: false, message: 'The run is ' + run.status + ', not approved.' });
        run.status = 'running';
        run.exec = call.body.n8n_execution_id;
        return send(res, 200, { success: true, data: { run_id: m[1], status: 'running', automation_run_id: '44444444-4444-4444-8444-444444444444', incident_id: run.incident_id, action_type: run.action_type, request_payload: { service_name: 'checkout-api' } } });
      }
      // complete_playbook_run: same checks and messages as the database function.
      const step = Array.isArray(scenario.complete) && scenario.complete.length ? scenario.complete.shift() : 'ok';
      call.answer = step;
      if (step === 'reset') { req.socket.destroy(); return; }
      if (step === 'timeout') return send(res, 503, { success: false, message: 'too late' }, late);
      if (typeof step === 'number') return send(res, step, { success: false, message: step >= 500 ? 'Failed to complete playbook run.' : 'Rejected (HTTP ' + step + ').' });
      if (run.status !== 'running') return send(res, 409, { success: false, message: 'The run is ' + run.status + ', not running.' });
      if (run.exec !== call.body.n8n_execution_id) return send(res, 403, { success: false, message: 'The execution id does not match this run.' });
      run.status = call.body.status;
      run.completions = (run.completions || 0) + 1;
      return send(res, 200, { success: true, data: { run_id: m[1], status: call.body.status, manual: false } }, step === 'timeout_commit' ? late : 0);
    }

    // BD-3: POST /api/machine/recovery-checks (validation like backend/src/routes/machine.routes.ts).
    if (req.url === '/api/machine/recovery-checks') {
      const b = call.body;
      const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      const obj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
      if (!obj(b) || !uuid.test(b.incident_id) || !uuid.test(b.playbook_run_id) || !['pending', 'healthy', 'unhealthy', 'failed'].includes(b.status)
        || (b.check_type !== undefined && b.check_type !== null && (typeof b.check_type !== 'string' || !b.check_type || b.check_type.length > 100))
        || (b.details !== undefined && !obj(b.details))) {
        call.answer = 400;
        return send(res, 400, { success: false, message: 'Invalid recovery check.' });
      }
      const mode = scenario.recovery_store;
      call.answer = mode;
      if (mode === 'not_found') return send(res, 404, { success: false, message: 'Incident not found.' });
      if (typeof mode === 'number') return send(res, mode, { success: false, message: 'Failed to record recovery check.' });
      const id = randomUUID();
      recoveryChecks.push({ id, ...b });
      return send(res, 201, { success: true, message: 'Recovery check recorded.', data: { recovery_check_id: id } });
    }
    // The other contract routes (analysis, incident-events) are not implemented
    // in the real backend yet: answer like Express does.
    return send(res, 404, { success: false, message: 'Route not found.' });
  });

  services.listen(servicesPort, '127.0.0.1');
  backend.listen(backendPort, '127.0.0.1');
  return {
    scenario,
    runs,
    calls,
    recoveryChecks,
    close: () => { services.close(); backend.close(); },
  };
}
