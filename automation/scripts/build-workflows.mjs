#!/usr/bin/env node
// Builds automation/workflows/*.json (importable n8n exports) from
// automation/src/nodes/** (Code node scripts) and automation/src/lib/** (shared
// helpers, inlined with //#include). Edit the sources, then run:
//   node automation/scripts/build-workflows.mjs
// Node type versions were checked against n8n 2.40.5.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = join(ROOT, 'src');

// ---------- ids ----------
export const WF = {
  groq: { id: 'dc33wf00groqtest', name: '00 - Groq Connection Test', file: '00-groq-test.json', owner: 'Tharindu' },
  intake: { id: 'dc33wf01alertint', name: '01 - Alert Intake', file: '01-alert-intake.json', owner: 'Vishwa' },
  logs: { id: 'dc33wf02loganaly', name: '02 - Log Analysis', file: '02-log-analysis.json', owner: 'Tharindu' },
  metrics: { id: 'dc33wf03metricsa', name: '03 - Metrics Analysis', file: '03-metrics-analysis.json', owner: 'Tharindu' },
  deploys: { id: 'dc33wf04deploycr', name: '04 - Deployment Correlation', file: '04-deployment-correlation.json', owner: 'Tharindu' },
  rca: { id: 'dc33wf05rootcaus', name: '05 - Root Cause Analysis', file: '05-root-cause.json', owner: 'Vishwa' },
  remediation: { id: 'dc33wf06remediat', name: '06 - Remediation', file: '06-remediation.json', owner: 'Vishwa' },
  recovery: { id: 'dc33wf07recovery', name: '07 - Recovery Check', file: '07-recovery-check.json', owner: 'Tharindu' },
  postmortem: { id: 'dc33wf08postmort', name: '08 - Postmortem', file: '08-postmortem.json', owner: 'Tharindu' },
  errors: { id: 'dc33wf09errorhnd', name: '09 - Error Handler', file: '09-error-handler.json', owner: 'Vishwa + Tharindu' },
};
export const CRED = {
  groq: { id: 'dc33credgroqapi1', name: 'Groq API' },
  github: { id: 'dc33credgithub01', name: 'GitHub API (read-only)' },
  alertmanager: { id: 'dc33credalertmgr', name: 'Alertmanager Webhook Token' },
};

const uuid = (seed) => {
  const h = createHash('sha256').update(seed).digest('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-4${h.slice(13, 16)}-a${h.slice(17, 20)}-${h.slice(20, 32)}`;
};

// ---------- code inlining ----------
// Every source is read with LF line endings (CRLF from a Windows checkout is
// converted), so the generated JSON is identical on Windows, macOS and Linux.
const readText = (file) => readFileSync(file, 'utf8').replace(/\r\n?/g, '\n');

export function buildCode(relFile) {
  const raw = readText(join(SRC, 'nodes', relFile));
  const seen = new Set();
  return raw.replace(/^\/\/#include(-text)? (\S+)(?: as (\w+))?\s*$/gm, (_, text, path, asName) => {
    if (text) {
      const content = readText(join(ROOT, path)).trim();
      return `const ${asName} = ${JSON.stringify(content)};`;
    }
    if (seen.has(path)) return '';
    seen.add(path);
    return readText(join(SRC, path)).trim();
  });
}

// Per-member copies in automation/team-workflows/<member>/workflows/ (09 is
// listed under Vishwa). Written by the build so they never go out of date.
export const teamDir = (owner) => (owner.startsWith('Vishwa') ? 'vishwa' : owner.toLowerCase());

// ---------- node builders ----------
function makeWorkflow(meta) {
  const nodes = [];
  const connections = {};
  const add = (name, type, typeVersion, col, row, parameters, extra = {}) => {
    nodes.push({ parameters, id: uuid(meta.id + '/' + name), name, type, typeVersion, position: [Math.round(col * 260), Math.round(row * 180)], ...extra });
    return name;
  };
  const wf = {
    meta,
    nodes,
    connections,
    link(from, to, fromOutput = 0, toInput = 0) {
      connections[from] = connections[from] || { main: [] };
      while (connections[from].main.length <= fromOutput) connections[from].main.push([]);
      connections[from].main[fromOutput].push({ node: to, type: 'main', index: toInput });
    },
    chain(...names) { for (let i = 0; i < names.length - 1; i++) this.link(names[i], names[i + 1]); },
    code(name, file, col, row, notes, opts = {}) {
      return add(name, 'n8n-nodes-base.code', 2, col, row, { jsCode: buildCode(file), ...(opts.parameters || {}) }, { notes, ...(opts.extra || {}) });
    },
    manual(name, col, row) { return add(name, 'n8n-nodes-base.manualTrigger', 1, col, row, {}); },
    subTrigger(name, col, row, notes) {
      return add(name, 'n8n-nodes-base.executeWorkflowTrigger', 1.1, col, row, { inputSource: 'passthrough' }, { notes });
    },
    errorTrigger(name, col, row) { return add(name, 'n8n-nodes-base.errorTrigger', 1, col, row, {}); },
    webhook(name, col, row, path, { headerAuth = null, rawBody = false, notes } = {}) {
      const p = { httpMethod: 'POST', path, responseMode: 'responseNode', options: rawBody ? { rawBody: true } : {} };
      const extra = { webhookId: uuid(meta.id + '/webhook/' + path), notes };
      if (headerAuth) { p.authentication = 'headerAuth'; extra.credentials = { httpHeaderAuth: headerAuth }; }
      return add(name, 'n8n-nodes-base.webhook', 2, col, row, p, extra);
    },
    respond(name, col, row, notes) {
      return add(name, 'n8n-nodes-base.respondToWebhook', 1.1, col, row, {
        respondWith: 'json',
        responseBody: '={{ JSON.stringify($json.response) }}',
        options: { responseCode: '={{ $json.http_status }}' },
      }, { notes });
    },
    // HTTP Request: full response + never error, so status codes are handled in
    // Code nodes; connection errors/timeouts continue as { error } items.
    http(name, col, row, { method = 'GET', url = '={{ $json.url }}', credential = null, headers = [], body = null, signed = false, retries = 2, notes }) {
      const p = { method, url };
      if (credential) { p.authentication = 'genericCredentialType'; p.genericAuthType = 'httpHeaderAuth'; }
      if (signed) {
        headers = [
          { name: 'X-DC-Timestamp', value: '={{ $json.request.headers["X-DC-Timestamp"] }}' },
          { name: 'X-DC-Nonce', value: '={{ $json.request.headers["X-DC-Nonce"] }}' },
          { name: 'X-DC-Signature', value: '={{ $json.request.headers["X-DC-Signature"] }}' },
        ];
        p.url = '={{ $json.request.url }}';
        body = { raw: '={{ $json.request.body }}' };
      }
      if (headers.length) { p.sendHeaders = true; p.headerParameters = { parameters: headers }; }
      if (body && body.raw) { p.sendBody = true; p.contentType = 'raw'; p.rawContentType = 'application/json'; p.body = body.raw; }
      if (body && body.json) { p.sendBody = true; p.specifyBody = 'json'; p.jsonBody = body.json; }
      p.options = {
        timeout: signed ? 15000 : '={{ $json.timeout_ms || 15000 }}',
        response: { response: { fullResponse: true, neverError: true } },
      };
      const extra = { onError: 'continueRegularOutput', notes };
      // Signed requests are never retried automatically: a retry would reuse the
      // nonce (the backend answers 409 "Replayed request").
      if (!signed && retries > 0) Object.assign(extra, { retryOnFail: true, maxTries: retries + 1, waitBetweenTries: 2000 });
      if (credential) extra.credentials = { httpHeaderAuth: credential };
      return add(name, 'n8n-nodes-base.httpRequest', 4.2, col, row, p, extra);
    },
    ifNode(name, col, row, leftValue, operator, rightValue, notes) {
      const condition = { id: uuid(meta.id + '/cond/' + name), leftValue, rightValue: rightValue === undefined ? '' : rightValue, operator };
      return add(name, 'n8n-nodes-base.if', 2.2, col, row, {
        conditions: { options: { caseSensitive: true, leftValue: '', typeValidation: 'loose', version: 2 }, conditions: [condition], combinator: 'and' },
        looseTypeValidation: true,
        options: {},
      }, { notes });
    },
    isTrue(name, col, row, expr, notes) { return this.ifNode(name, col, row, expr, { type: 'boolean', operation: 'true', singleValue: true }, undefined, notes); },
    equals(name, col, row, expr, value, notes) { return this.ifNode(name, col, row, expr, { type: 'string', operation: 'equals' }, value, notes); },
    switchOn(name, col, row, expr, values, fallbackName, notes) {
      return add(name, 'n8n-nodes-base.switch', 3.2, col, row, {
        rules: {
          values: values.map((v) => ({
            conditions: { options: { caseSensitive: true, leftValue: '', typeValidation: 'strict', version: 2 }, conditions: [{ id: uuid(meta.id + '/sw/' + v), leftValue: expr, rightValue: v, operator: { type: 'string', operation: 'equals' } }], combinator: 'and' },
            renameOutput: true,
            outputKey: v,
          })),
        },
        options: { fallbackOutput: 'extra', renameFallbackOutput: fallbackName },
      }, { notes });
    },
    mergeAppend(name, col, row, inputs, notes) { return add(name, 'n8n-nodes-base.merge', 3, col, row, { numberInputs: inputs }, { notes }); },
    mergeByPosition(name, col, row, notes) { return add(name, 'n8n-nodes-base.merge', 3, col, row, { mode: 'combine', combineBy: 'combineByPosition', options: {} }, { notes }); },
    execute(name, col, row, target, notes, mode = 'once') {
      return add(name, 'n8n-nodes-base.executeWorkflow', 1.2, col, row, {
        source: 'database',
        workflowId: { __rl: true, value: target.id, mode: 'list', cachedResultName: target.name },
        workflowInputs: { mappingMode: 'defineBelow', value: {}, matchingColumns: [], schema: [], attemptToConvertTypes: false, convertFieldsToString: true },
        mode,
        options: { waitForSubWorkflow: true },
      }, { notes, onError: 'continueRegularOutput' });
    },
    wait(name, col, row, notes) { return add(name, 'n8n-nodes-base.wait', 1.1, col, row, { resume: 'timeInterval', amount: '={{ $json.wait_seconds }}', unit: 'seconds' }, { notes, webhookId: uuid(meta.id + '/wait/' + name) }); },
    set(name, col, row, assignments, notes) {
      return add(name, 'n8n-nodes-base.set', 3.4, col, row, {
        mode: 'manual',
        assignments: { assignments: assignments.map(([n, v, t]) => ({ id: uuid(meta.id + '/set/' + name + n), name: n, value: v, type: t || 'string' })) },
        includeOtherFields: true,
        options: {},
      }, { notes });
    },
    noop(name, col, row, notes) { return add(name, 'n8n-nodes-base.noOp', 1, col, row, {}, { notes }); },
    sticky(text, col, row, width = 520, height = 300) {
      nodes.push({ parameters: { content: text, width, height }, id: uuid(meta.id + '/sticky/' + col + '/' + row), name: 'Note ' + (nodes.filter((n) => n.type.endsWith('stickyNote')).length + 1), type: 'n8n-nodes-base.stickyNote', typeVersion: 1, position: [col * 260, row * 180] });
    },
    toJSON() {
      return {
        id: meta.id,
        name: meta.name,
        nodes,
        connections,
        active: false,
        settings: {
          executionOrder: 'v1',
          saveManualExecutions: true,
          callerPolicy: 'workflowsFromSameOwner',
          ...(meta.id === WF.errors.id ? {} : { errorWorkflow: WF.errors.id }),
        },
        pinData: {},
        meta: { templateCredsSetupCompleted: false },
        tags: [],
      };
    },
  };
  return wf;
}

const GITHUB_HEADERS = [
  { name: 'Accept', value: 'application/vnd.github+json' },
  { name: 'X-GitHub-Api-Version', value: '2022-11-28' },
];
const groqHttp = (w, name, col, row) => w.http(name, col, row, {
  method: 'POST', credential: CRED.groq, body: { json: '={{ JSON.stringify($json.groq_request) }}' }, retries: 1,
  notes: 'Groq chat completions (OpenAI-compatible). Auth: n8n credential "Groq API" (Header Auth: Authorization = Bearer <key>).',
});

// ---------- 00 Groq Connection Test (Tharindu) ----------
function wf00() {
  const w = makeWorkflow(WF.groq);
  w.sticky('## 00 – Groq Connection Test (owner: Tharindu)\nRun manually after setting up the **Groq API** credential and `GROQ_MODEL`.\nResult: **PASS** or **FAIL** with a hint (bad key, rate limit, timeout, invalid model, invalid response).', 0, -2, 600, 200);
  w.manual('Run test', 0, 0);
  w.code('Build test request', '00-groq-test/build-test-request.js', 1, 0, 'Reads GROQ_MODEL / GROQ_API_BASE_URL. No key here: the key is in the credential.');
  groqHttp(w, 'Groq: chat completion', 2, 0);
  w.code('Validate Groq response', '00-groq-test/validate-response.js', 3, 0, 'Classifies: auth, rate_limited, timeout, unavailable, client_error, invalid_response.');
  w.isTrue('Groq OK?', 4, 0, '={{ $json.ok }}');
  w.set('PASS', 5, -1, [['result', 'PASS']]);
  w.set('FAIL', 5, 1, [['result', 'FAIL']]);
  w.chain('Run test', 'Build test request', 'Groq: chat completion', 'Validate Groq response', 'Groq OK?');
  w.link('Groq OK?', 'PASS', 0); w.link('Groq OK?', 'FAIL', 1);
  return w;
}

// ---------- 01 Alert Intake (Vishwa) ----------
function wf01() {
  const w = makeWorkflow(WF.intake);
  w.sticky('## 01 – Alert Intake (owner: Vishwa)\nAlertmanager → validate → de-duplicate → respond 202 → create incident (**BLOCKED: BD-1**) → run 05 Root Cause for every new alert.\nAuth: Header Auth credential "Alertmanager Webhook Token" (Alertmanager sends `Authorization: Bearer <token>`).', 0, -2, 700, 220);
  w.webhook('Alertmanager webhook', 0, 0, 'alertmanager', { headerAuth: CRED.alertmanager, notes: 'POST /webhook/alertmanager (Alertmanager webhook_config, version 4 payload).' });
  w.code('Parse and validate alerts', '01-alert-intake/parse-alerts.js', 1, 0, 'Firing alerts only; resolved alerts are acknowledged.');
  w.isTrue('Valid payload?', 2, 0, '={{ $json.valid }}');
  w.respond('Respond 400', 3, 1, 'Invalid payload.');
  w.code('Detect duplicate alerts', '01-alert-intake/dedupe.js', 3, -1, 'fingerprint + startsAt, kept DEDUP_WINDOW_MINUTES (static data; production executions only).');
  w.set('Accepted response', 4, -1, [['http_status', '={{ 202 }}', 'number']], 'Adds the HTTP status for the response.');
  w.respond('Respond 202', 5, -1, 'Answers Alertmanager before the long investigation starts.');
  w.code('Create incident (backend) – BLOCKED', '01-alert-intake/create-incident.js', 6, -1, 'BLOCKED (BD-1): no backend endpoint creates incidents from alerts. No URL is invented.');
  w.execute('Run 05 Root Cause', 7, -1, WF.rca, 'One sub-workflow run per new alert.', 'each');
  w.code('Intake result', '01-alert-intake/intake-result.js', 8, -1);
  w.chain('Alertmanager webhook', 'Parse and validate alerts', 'Valid payload?');
  w.link('Valid payload?', 'Detect duplicate alerts', 0);
  w.link('Valid payload?', 'Respond 400', 1);
  w.chain('Detect duplicate alerts', 'Accepted response', 'Respond 202', 'Create incident (backend) – BLOCKED', 'Run 05 Root Cause', 'Intake result');
  return w;
}

// ---------- 02/03/04 investigation sub-workflows (Tharindu) ----------
function investigation(meta, title, buildName, buildFile, httpName, httpOpts, analyzeName, analyzeFile, noteText) {
  const w = makeWorkflow(meta);
  w.sticky(noteText, 0, -2, 700, 220);
  w.subTrigger('When called by 05 Root Cause', 0, 0, 'Input: { incident_id, service_name, alert_name, severity, started_at }');
  w.code(buildName, buildFile, 1, 0);
  w.isTrue('Request ready?', 2, 0, '={{ !$json.skip }}');
  w.http(httpName, 3, -1, httpOpts);
  w.code(analyzeName, analyzeFile, 4, -1, 'Returns automation/schemas/investigation-output.schema.json');
  w.code('Return skipped result', '02-log-analysis/skip-result.js', 3, 1, 'Invalid input or source not configured: no HTTP call.');
  w.chain('When called by 05 Root Cause', buildName, 'Request ready?');
  w.link('Request ready?', httpName, 0);
  w.link('Request ready?', 'Return skipped result', 1);
  w.link(httpName, analyzeName);
  return w;
}
const wf02 = () => investigation(WF.logs, 'logs', 'Build LogQL query', '02-log-analysis/build-query.js', 'Loki: query_range', { notes: 'GET {LOKI_URL}/loki/api/v1/query_range (no auth for the local Loki).' }, 'Analyze logs', '02-log-analysis/analyze-logs.js',
  '## 02 – Log Analysis (owner: Tharindu)\nLoki `query_range` for error/warning lines of the service around `started_at`.\nConfig: `LOKI_URL`, `LOKI_SERVICE_LABEL` (**confirm with Keshan**), `LOKI_LOOKBACK_MINUTES`, `LOKI_MAX_LINES`.');
const wf03 = () => investigation(WF.metrics, 'metrics', 'Build PromQL queries', '03-metrics-analysis/build-queries.js', 'Prometheus: instant query', { notes: 'GET {PROMETHEUS_URL}/api/v1/query, one call per metric and phase.' }, 'Evaluate metrics', '03-metrics-analysis/evaluate-metrics.js',
  '## 03 – Metrics Analysis (owner: Tharindu)\nCurrent vs baseline for cpu, memory (prom-client defaults) and error_rate / latency_p95 / request_rate (only when `PROM_QUERY_*` is set).\nAbnormal = above `PROM_THRESHOLD_*` or ≥ `PROM_ANOMALY_FACTOR` × baseline.');
const wf04 = () => investigation(WF.deploys, 'deployments', 'Build GitHub requests', '04-deployment-correlation/build-requests.js', 'GitHub API', { credential: CRED.github, headers: GITHUB_HEADERS, notes: 'GET /repos/{owner}/{repo}/commits and /actions/runs. Credential: fine-grained token, read-only.' }, 'Correlate changes', '04-deployment-correlation/correlate.js',
  '## 04 – Deployment Correlation (owner: Tharindu)\nCommits + GitHub Actions runs before the incident. "Suspect" = within `DEPLOY_SUSPECT_MINUTES`. Correlation is a **possible** cause, never a confirmed one.');

// ---------- 05 Root Cause Analysis (Vishwa) ----------
function wf05() {
  const w = makeWorkflow(WF.rca);
  w.sticky('## 05 – Root Cause Analysis (owner: Vishwa)\nRuns 02, 03, 04 → combines evidence → Groq (only if some source found evidence) → validates against `rca-output.schema.json` → stores via `POST /api/machine/investigations/:id/analysis` (**contract path, backend route not implemented: BD-2**).\nThe AI result is data only. Nothing here starts a remediation.', 0, -3, 800, 240);
  w.subTrigger('When called by 01 Alert Intake', 0, 0, 'Input: { incident_id|null, investigation_id|null, service_name, alert_name, severity, started_at, summary }');
  w.code('Validate RCA input', '05-root-cause/validate-input.js', 1, 0);
  w.isTrue('Input valid?', 2, 0, '={{ $json.valid }}');
  w.code('RCA result (invalid input)', '05-root-cause/input-error.js', 3, 2);
  w.execute('Run 02 Log Analysis', 3, -1, WF.logs, 'A failure continues as { error } (partial evidence).');
  w.execute('Run 03 Metrics Analysis', 3, 0, WF.metrics, 'A failure continues as { error } (partial evidence).');
  w.execute('Run 04 Deployment Correlation', 3, 1, WF.deploys, 'A failure continues as { error } (partial evidence).');
  w.mergeAppend('Collect results', 4, 0, 3);
  w.code('Combine evidence', '05-root-cause/combine-evidence.js', 5, 0, 'decision: analyze | no_evidence | sources_unavailable');
  w.equals('Evidence found?', 6, 0, '={{ $json.decision }}', 'analyze');
  w.code('RCA result (no AI call)', '05-root-cause/result-no-ai.js', 7, 1, 'No evidence or all sources failed: the AI is not asked to guess.');
  w.code('Build RCA prompt', '05-root-cause/build-prompt.js', 7, -1, 'System prompt: automation/prompts/rca-system-prompt.txt');
  groqHttp(w, 'Groq: RCA', 8, -1);
  w.code('Validate RCA', '05-root-cause/validate-rca.js', 9, -1, 'Schema: automation/schemas/rca-output.schema.json');
  w.isTrue('Can store?', 10, -1, '={{ $json.can_store }}', 'Needs a valid RCA + incident_id + investigation_id.');
  w.code('Sign store request', '05-root-cause/sign-store.js', 11, -2, 'HMAC (MACHINE_SIGNING_SECRET from the environment).');
  w.http('Backend: store AI analysis', 12, -2, { method: 'POST', signed: true, notes: 'POST {BACKEND_BASE_URL}/api/machine/investigations/:id/analysis (BD-2: 404 until implemented).' });
  w.code('RCA result (store attempted)', '05-root-cause/result-stored.js', 13, -2);
  w.code('RCA result (not stored)', '05-root-cause/result-not-stored.js', 11, 0);
  w.chain('When called by 01 Alert Intake', 'Validate RCA input', 'Input valid?');
  w.link('Input valid?', 'Run 02 Log Analysis', 0);
  w.link('Input valid?', 'Run 03 Metrics Analysis', 0);
  w.link('Input valid?', 'Run 04 Deployment Correlation', 0);
  w.link('Input valid?', 'RCA result (invalid input)', 1);
  w.link('Run 02 Log Analysis', 'Collect results', 0, 0);
  w.link('Run 03 Metrics Analysis', 'Collect results', 0, 1);
  w.link('Run 04 Deployment Correlation', 'Collect results', 0, 2);
  w.chain('Collect results', 'Combine evidence', 'Evidence found?');
  w.link('Evidence found?', 'Build RCA prompt', 0);
  w.link('Evidence found?', 'RCA result (no AI call)', 1);
  w.chain('Build RCA prompt', 'Groq: RCA', 'Validate RCA', 'Can store?');
  w.link('Can store?', 'Sign store request', 0);
  w.link('Can store?', 'RCA result (not stored)', 1);
  w.chain('Sign store request', 'Backend: store AI analysis', 'RCA result (store attempted)');
  return w;
}

// ---------- 06 Remediation (Vishwa) ----------
function wf06() {
  const w = makeWorkflow(WF.remediation);
  w.sticky('## 06 – Remediation (owner: Vishwa)\nBackend → `POST /webhook/remediation` (HMAC signed) → verify signature, time window, nonce → **backend start** (`start_playbook_run` only succeeds for an APPROVED run) → fixed branch per action → **backend complete** → 07 Recovery Check.\nNever executes commands from the webhook or the AI. **Execution integration is BLOCKED** (no playbook executor yet): `REMEDIATION_EXECUTION_MODE=disabled` refuses; `simulate` records a clearly marked simulated result for tests.', 0, -4, 900, 260);
  w.webhook('Remediation webhook', 0, 0, 'remediation', { rawBody: true, notes: 'POST /webhook/remediation. Raw Body ON: the signature covers the exact bytes.' });
  w.code('Verify signature and payload', '06-remediation/verify-request.js', 1, 0, 'HMAC-SHA256, 300 s window, nonce once (static data), strict body.');
  w.isTrue('Request valid?', 2, 0, '={{ $json.valid }}');
  w.respond('Respond rejected', 3, 2, '401 bad signature / 409 replay / 400 bad body / 503 not configured.');
  w.equals('Execution available?', 3, 0, '={{ $json.execution_mode }}', 'simulate', 'disabled (default) → refuse before the run is started.');
  w.set('Execution blocked response', 4, 1, [['http_status', '={{ 503 }}', 'number'], ['response', '={{ { accepted: false, message: "Remediation execution integration is not available (BLOCKED: no playbook executor). The run was not started." } }}', 'object']]);
  w.respond('Respond 503', 5, 1);
  w.code('Sign start request', '06-remediation/sign-start.js', 4, -1);
  w.http('Backend: start run', 5, -1, { method: 'POST', signed: true, notes: 'POST /api/machine/playbook-runs/:id/start → start_playbook_run (approval enforced in the database).' });
  w.code('Check start result', '06-remediation/check-start.js', 6, -1, 'Uses the action_type returned by the DATABASE.');
  w.isTrue('Run started?', 7, -1, '={{ $json.started }}');
  w.respond('Respond 202', 8, -2);
  w.switchOn('Action type', 9, -2, '={{ $json.action_type }}', ['restart', 'rollback', 'scale', 'circuit_breaker'], 'unsupported');
  const actions = ['restart', 'rollback', 'scale', 'circuit_breaker'];
  actions.forEach((a, i) => {
    const name = 'Execute: ' + a;
    w.code(name, '06-remediation/execute-action.js', 10, -3.5 + i, 'BLOCKED: no executor. simulate mode only. No shell commands.');
    const n = w.nodes.find((x) => x.name === name);
    n.parameters.jsCode = n.parameters.jsCode.replace("'__ACTION__'", JSON.stringify(a));
    w.link('Action type', name, i);
    w.link(name, 'Sign complete request');
  });
  w.code('Unsupported or rejected action', '06-remediation/unsupported-action.js', 10, 0.5, 'Completes the run as failed. Nothing is executed.');
  w.link('Action type', 'Unsupported or rejected action', 4);
  w.respond('Respond refused', 8, 0, 'Backend refused (not approved / not found) or mismatch.');
  w.isTrue('Started but mismatched?', 9, 0, '={{ $json.started_but_rejected === true }}', 'A started run must be completed (as failed).');
  w.code('Sign complete request', '06-remediation/sign-complete.js', 11, -1);
  w.http('Backend: complete run', 12, -1, { method: 'POST', signed: true, notes: 'POST /api/machine/playbook-runs/:id/complete (same n8n_execution_id).' });
  w.code('Check completion', '06-remediation/check-complete.js', 13, -1);
  w.isTrue('Check recovery?', 14, -1, '={{ $json.check_recovery }}', 'Only after a reported success.');
  w.execute('Run 07 Recovery Check', 15, -2, WF.recovery, 'Recovery verification (Tharindu).');
  w.noop('Done (no recovery check)', 15, 0);
  w.chain('Remediation webhook', 'Verify signature and payload', 'Request valid?');
  w.link('Request valid?', 'Execution available?', 0);
  w.link('Request valid?', 'Respond rejected', 1);
  w.link('Execution available?', 'Sign start request', 0);
  w.link('Execution available?', 'Execution blocked response', 1);
  w.link('Execution blocked response', 'Respond 503');
  w.chain('Sign start request', 'Backend: start run', 'Check start result', 'Run started?');
  w.link('Run started?', 'Respond 202', 0);
  w.link('Run started?', 'Respond refused', 1);
  w.link('Respond 202', 'Action type');
  w.link('Respond refused', 'Started but mismatched?');
  w.link('Started but mismatched?', 'Unsupported or rejected action', 0);
  w.link('Unsupported or rejected action', 'Sign complete request');
  w.chain('Sign complete request', 'Backend: complete run', 'Check completion', 'Check recovery?');
  w.link('Check recovery?', 'Run 07 Recovery Check', 0);
  w.link('Check recovery?', 'Done (no recovery check)', 1);
  return w;
}

// ---------- 07 Recovery Check (Tharindu) ----------
function wf07() {
  const w = makeWorkflow(WF.recovery);
  w.sticky('## 07 – Recovery Check (owner: Tharindu)\nWait `RECOVERY_WAIT_SECONDS` → query Prometheus (`up` + error rate) → repeat up to `RECOVERY_MAX_CHECKS` → verdict **recovered / not_recovered / unable_to_verify** → store via `POST /api/machine/recovery-checks` (**contract path, not implemented: BD-3**) → 08 Postmortem when recovered.', 0, -3, 800, 240);
  w.subTrigger('When called by 06 Remediation', 0, 0, 'Input: { incident_id, playbook_run_id, service_name, action_type, simulated }');
  w.code('Plan recovery check', '07-recovery-check/plan.js', 1, 0);
  w.isTrue('Can verify?', 2, 0, '={{ $json.can_verify }}');
  w.wait('Wait before check', 3, -1, 'RECOVERY_WAIT_SECONDS');
  w.code('Build health queries', '07-recovery-check/build-health-queries.js', 4, -1);
  w.http('Prometheus: health query', 5, -2, { notes: 'GET {PROMETHEUS_URL}/api/v1/query' });
  w.mergeByPosition('Pair query and answer', 6, -1);
  w.code('Evaluate health', '07-recovery-check/evaluate-health.js', 7, -1);
  w.isTrue('Verdict reached?', 8, -1, '={{ $json.done }}', 'false → wait and check again (max RECOVERY_MAX_CHECKS).');
  w.code('Sign recovery check request', '07-recovery-check/sign-store.js', 9, 0, 'Verdict → recovery_checks.status: healthy / unhealthy / failed');
  w.isTrue('Store?', 10, 0, '={{ !$json.skip_store }}');
  w.http('Backend: store recovery check', 11, -1, { method: 'POST', signed: true, notes: 'POST /api/machine/recovery-checks (BD-3: 404 until implemented).' });
  w.code('Recovery result', '07-recovery-check/result.js', 12, 0);
  w.equals('Recovered?', 13, 0, '={{ $json.status }}', 'recovered');
  w.execute('Run 08 Postmortem', 14, -1, WF.postmortem, 'Draft postmortem (Tharindu).');
  w.noop('Done (not recovered)', 14, 1);
  w.code('Return recovery result', '07-recovery-check/attach-postmortem.js', 15, -1, 'Always returns the recovery result (plus the postmortem status).');
  w.chain('When called by 06 Remediation', 'Plan recovery check', 'Can verify?');
  w.link('Can verify?', 'Wait before check', 0);
  w.link('Can verify?', 'Sign recovery check request', 1);
  w.chain('Wait before check', 'Build health queries', 'Prometheus: health query');
  w.link('Prometheus: health query', 'Pair query and answer', 0, 0);
  w.link('Build health queries', 'Pair query and answer', 0, 1);
  w.chain('Pair query and answer', 'Evaluate health', 'Verdict reached?');
  w.link('Verdict reached?', 'Sign recovery check request', 0);
  w.link('Verdict reached?', 'Wait before check', 1);
  w.link('Sign recovery check request', 'Store?');
  w.link('Store?', 'Backend: store recovery check', 0);
  w.link('Store?', 'Recovery result', 1);
  w.link('Backend: store recovery check', 'Recovery result');
  w.link('Recovery result', 'Recovered?');
  w.link('Recovered?', 'Run 08 Postmortem', 0);
  w.link('Recovered?', 'Done (not recovered)', 1);
  w.link('Run 08 Postmortem', 'Return recovery result');
  return w;
}

// ---------- 08 Postmortem (Tharindu) ----------
function wf08() {
  const w = makeWorkflow(WF.postmortem);
  w.sticky('## 08 – Postmortem (owner: Tharindu)\nUses the context passed by 07 (backend read endpoints missing: **BD-4**) → Groq → validate against `postmortem-output.schema.json` → store (**BLOCKED: BD-4**, draft returned in the execution output).', 0, -3, 800, 220);
  w.subTrigger('When called by 07 Recovery Check', 0, 0, 'Input: recovery result (+ optional rca, incident, timeline).');
  w.code('Collect incident context', '08-postmortem/collect-context.js', 1, 0, 'BLOCKED (BD-4): no machine endpoint to read incident/RCA/run data.');
  w.isTrue('Enough context?', 2, 0, '={{ $json.enough }}');
  w.code('Not enough context', '08-postmortem/not-enough.js', 3, 1);
  w.code('Build postmortem prompt', '08-postmortem/build-prompt.js', 3, -1, 'System prompt: automation/prompts/postmortem-system-prompt.txt');
  groqHttp(w, 'Groq: postmortem', 4, -1);
  w.code('Validate postmortem', '08-postmortem/validate-postmortem.js', 5, -1);
  w.code('Store postmortem (backend) – BLOCKED', '08-postmortem/store-blocked.js', 6, -1, 'BLOCKED (BD-4): no endpoint. No URL is invented.');
  w.chain('When called by 07 Recovery Check', 'Collect incident context', 'Enough context?');
  w.link('Enough context?', 'Build postmortem prompt', 0);
  w.link('Enough context?', 'Not enough context', 1);
  w.chain('Build postmortem prompt', 'Groq: postmortem', 'Validate postmortem', 'Store postmortem (backend) – BLOCKED');
  return w;
}

// ---------- 09 Error Handler (shared) ----------
function wf09() {
  const w = makeWorkflow(WF.errors);
  w.sticky('## 09 – Error Handler (shared)\nSet as "Error workflow" of 00–08. Builds a short, redacted summary (no stack, no data) and posts it to `ERROR_NOTIFY_WEBHOOK_URL` (Slack or Discord incoming webhook) when configured.', 0, -2, 700, 200);
  w.errorTrigger('On workflow error', 0, 0);
  w.code('Summarize error', '09-error-handler/summarize-error.js', 1, 0, 'Redacts tokens, keys, JWTs and webhook URLs.');
  w.isTrue('Notification configured?', 2, 0, '={{ $json.notify }}');
  // The secret webhook URL is read from the environment by this node only, so it
  // never appears in an item (n8n stores node output in the execution history).
  w.http('Send notification', 3, -1, { method: 'POST', url: '={{ $env.ERROR_NOTIFY_WEBHOOK_URL }}', body: { raw: '={{ $json.body }}' }, retries: 1, notes: 'POST ERROR_NOTIFY_WEBHOOK_URL. The URL is a secret: it is read from the environment here and never written to an item.' });
  w.noop('Logged only', 3, 1, 'The summary stays in the n8n execution log.');
  w.chain('On workflow error', 'Summarize error', 'Notification configured?');
  w.link('Notification configured?', 'Send notification', 0);
  w.link('Notification configured?', 'Logged only', 1);
  return w;
}

export const BUILDERS = [wf00, wf01, wf02, wf03, wf04, wf05, wf06, wf07, wf08, wf09];

export function buildAll() {
  return BUILDERS.map((b) => { const w = b(); return { meta: w.meta, json: w.toJSON() }; });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const out = join(ROOT, 'workflows');
  mkdirSync(out, { recursive: true });
  for (const { meta, json } of buildAll()) {
    const text = JSON.stringify(json, null, 2) + '\n';
    writeFileSync(join(out, meta.file), text);
    const team = join(ROOT, 'team-workflows', teamDir(meta.owner), 'workflows');
    mkdirSync(team, { recursive: true });
    writeFileSync(join(team, meta.file), text);
    console.log('wrote workflows/' + meta.file + ' + team-workflows/' + teamDir(meta.owner) + ' (' + json.nodes.length + ' nodes)');
  }
}
