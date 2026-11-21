// Workflow 03 – Metrics Analysis (owner: Tharindu)
// Node: "Build PromQL queries". One item per (metric, phase): the value at the
// incident time ("current") and at a baseline time before it ("baseline").
//
// Metric names are NOT invented here:
// - cpu / memory default to prom-client's built-in default metrics
//   (process_cpu_seconds_total, process_resident_memory_bytes), which the sample
//   app is planned to expose; confirm with the monitoring owner.
// - error_rate / latency_p95 / request_rate have no default: they depend on the
//   app's own metrics and must be set in PROM_QUERY_* (otherwise "not_configured").
// Every query is a template where {{service}} is replaced by the service name.
//#include lib/common.js

const env = $env;
const input = readInvestigationInput($input.first().json);
const ctx = input.ctx;

if (!input.ok) {
  return [{ json: { skip: true, result: investigationResult('metrics', ctx, { status: 'invalid_input', error: { kind: 'invalid_input', message: input.error } }) } }];
}
const promUrl = String(env.PROMETHEUS_URL || '').replace(/\/+$/, '');
if (!/^https?:\/\//.test(promUrl)) {
  return [{ json: { skip: true, result: investigationResult('metrics', ctx, { status: 'not_configured', summary: 'Prometheus is not configured (PROMETHEUS_URL).', error: { kind: 'not_configured', message: 'Set PROMETHEUS_URL in the n8n environment.' } }) } }];
}

const label = String(env.PROM_SERVICE_LABEL || 'job');
if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(label)) throw new Error('PROM_SERVICE_LABEL is not a valid label name.');
const sel = label + '="{{service}}"';

const METRICS = [
  { name: 'cpu', unit: 'cores', env: 'PROM_QUERY_CPU', fallback: 'sum(rate(process_cpu_seconds_total{' + sel + '}[5m]))', threshold: 'PROM_THRESHOLD_CPU' },
  { name: 'memory', unit: 'bytes', env: 'PROM_QUERY_MEMORY', fallback: 'sum(process_resident_memory_bytes{' + sel + '})', threshold: 'PROM_THRESHOLD_MEMORY' },
  { name: 'error_rate', unit: 'ratio', env: 'PROM_QUERY_ERROR_RATE', fallback: null, threshold: 'PROM_THRESHOLD_ERROR_RATE' },
  { name: 'latency_p95', unit: 'seconds', env: 'PROM_QUERY_LATENCY_P95', fallback: null, threshold: 'PROM_THRESHOLD_LATENCY_P95' },
  { name: 'request_rate', unit: 'req/s', env: 'PROM_QUERY_REQUEST_RATE', fallback: null, threshold: null },
];

const started = new Date(ctx.started_at).getTime();
const baselineOffset = envInt(env, 'PROM_BASELINE_OFFSET_MINUTES', 30, 5, 1440);
const times = { current: new Date(Math.min(Date.now(), started + 2 * 60000)), baseline: new Date(started - baselineOffset * 60000) };
const timeout = envInt(env, 'PROMETHEUS_TIMEOUT_MS', 10000, 1000, 60000);

const items = [];
const notConfigured = [];
for (const m of METRICS) {
  const template = env[m.env] || m.fallback;
  if (!template) { notConfigured.push(m.name); continue; }
  const query = String(template).split('{{service}}').join(ctx.service_name);
  for (const phase of ['current', 'baseline']) {
    items.push({
      json: {
        skip: false,
        ctx,
        metric: m.name,
        unit: m.unit,
        phase,
        query,
        at: times[phase].toISOString(),
        threshold: m.threshold && env[m.threshold] !== undefined && env[m.threshold] !== '' ? Number(env[m.threshold]) : null,
        not_configured: notConfigured,
        url: promUrl + '/api/v1/query?' + toQuery({ query, time: times[phase].toISOString() }),
        timeout_ms: timeout,
      },
    });
  }
}
if (!items.length) {
  return [{ json: { skip: true, result: investigationResult('metrics', ctx, { status: 'not_configured', summary: 'No PromQL queries are configured.', error: { kind: 'not_configured', message: 'Set PROM_QUERY_* in the n8n environment.' } }) } }];
}
// not_configured is final only after the loop; copy it onto every item.
for (const it of items) it.json.not_configured = notConfigured;
return items;
