// Workflow 03 – Node: "Evaluate metrics". Pairs every Prometheus answer with
// its request (same position), compares current vs baseline and thresholds.
// A metric is abnormal when it is above its configured threshold, or when it is
// at least PROM_ANOMALY_FACTOR times its baseline (default 2).
//#include lib/common.js

const env = $env;
const reqs = $('Build PromQL queries').all().map((i) => i.json);
const resps = $input.all().map((i) => i.json);
const ctx = reqs[0].ctx;
const factor = envNumber(env, 'PROM_ANOMALY_FACTOR', 2);

const metrics = {};
let failures = 0;
let lastError = null;
reqs.forEach((req, idx) => {
  const r = resps[idx] || {};
  const m = metrics[req.metric] || (metrics[req.metric] = { name: req.metric, unit: req.unit, query: req.query, threshold: req.threshold, current: null, baseline: null, errors: [] });
  const c = classifyHttp(r);
  if (c.kind !== 'ok') {
    failures++;
    lastError = { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message };
    m.errors.push(req.phase + ': ' + c.kind);
    return;
  }
  const b = r.body;
  if (!b || b.status !== 'success' || !b.data || !Array.isArray(b.data.result)) {
    failures++;
    lastError = { kind: 'invalid_response', message: 'Unexpected Prometheus response.' };
    m.errors.push(req.phase + ': invalid response');
    return;
  }
  // Sum all series of an instant vector (queries already aggregate with sum()).
  const values = b.data.result.map((s) => Number(s.value && s.value[1])).filter((v) => Number.isFinite(v));
  m[req.phase] = values.length ? values.reduce((a, v) => a + v, 0) : null;
});

const all = Object.values(metrics);
const window = { current_at: (reqs.find((r) => r.phase === 'current') || {}).at, baseline_at: (reqs.find((r) => r.phase === 'baseline') || {}).at };

if (failures === reqs.length) {
  const status = lastError && lastError.kind === 'client_error' ? 'query_rejected' : lastError && lastError.kind === 'invalid_response' ? 'invalid_response' : 'unavailable';
  return [{ json: investigationResult('metrics', ctx, { status, window, summary: 'Prometheus queries failed.', error: lastError }) }];
}

const findings = [];
const evidence = [];
const missing = [];
let abnormal = 0;
for (const m of all) {
  if (m.current === null) { missing.push(m.name); continue; }
  const ratio = m.baseline && m.baseline > 0 ? m.current / m.baseline : null;
  const reasons = [];
  if (m.threshold !== null && Number.isFinite(m.threshold) && m.current > m.threshold) reasons.push('above threshold ' + m.threshold);
  if (ratio !== null && ratio >= factor) reasons.push(ratio.toFixed(1) + 'x baseline');
  if ((m.baseline === 0 || m.baseline === null) && m.current > 0 && m.name === 'error_rate') reasons.push('errors appeared (baseline 0)');
  m.abnormal = reasons.length > 0;
  const fmt = (v) => (v === null ? 'n/a' : Math.abs(v) >= 1000 ? v.toExponential(2) : Number(v.toFixed(4)));
  evidence.push({ type: 'metric', source: 'prometheus', metric: m.name, unit: m.unit, query: m.query, current: m.current, baseline: m.baseline, ratio: ratio === null ? null : Number(ratio.toFixed(2)), abnormal: m.abnormal });
  if (m.abnormal) {
    abnormal++;
    findings.push(m.name + ' is abnormal: ' + fmt(m.current) + ' ' + m.unit + ' (baseline ' + fmt(m.baseline) + '; ' + reasons.join(', ') + ').');
  }
}
const notConfigured = reqs[0].not_configured || [];
if (missing.length) findings.push('No data for: ' + missing.join(', ') + ' (metric missing or label mismatch).');
if (notConfigured.length) findings.push('Not configured: ' + notConfigured.join(', ') + ' (set PROM_QUERY_* to enable).');

const partial = failures > 0 ? { kind: 'partial', message: failures + ' of ' + reqs.length + ' queries failed', last: lastError } : null;
if (abnormal === 0) {
  return [{ json: investigationResult('metrics', ctx, { status: evidence.length ? 'no_evidence' : 'unavailable', window, summary: evidence.length ? 'No abnormal metrics for ' + ctx.service_name + '.' : 'No metric data found for ' + ctx.service_name + '.', findings, evidence, confidence: 0.2, error: partial || (evidence.length ? null : { kind: 'no_data', message: 'All configured metrics returned no data.' }) }) }];
}
return [{ json: investigationResult('metrics', ctx, { status: 'evidence_found', window, summary: abnormal + ' abnormal metric(s) for ' + ctx.service_name + '.', findings, evidence, confidence: Math.min(0.9, 0.5 + 0.15 * abnormal), error: partial }) }];
