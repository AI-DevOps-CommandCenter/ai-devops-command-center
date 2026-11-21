// Workflow 02 – Node: "Analyze logs". Reads the Loki response, classifies the
// lines and returns the standard investigation result.
//#include lib/common.js

const req = $('Build LogQL query').first().json;
const ctx = req.ctx;
const response = $input.first().json;
const c = classifyHttp(response);

if (c.kind !== 'ok') {
  const status = c.kind === 'client_error' ? 'query_rejected' : 'unavailable';
  return [{ json: investigationResult('logs', ctx, { status, window: req.window, summary: 'Loki query failed (' + c.kind + ').', error: { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message } }) }];
}

const body = response.body;
if (!body || body.status !== 'success' || !body.data || !Array.isArray(body.data.result)) {
  return [{ json: investigationResult('logs', ctx, { status: 'invalid_response', window: req.window, summary: 'Loki returned an unexpected response.', error: { kind: 'invalid_response', message: 'Expected data.result[] with status "success".' } }) }];
}

const lines = [];
for (const stream of body.data.result) {
  for (const v of stream.values || []) {
    if (!Array.isArray(v) || v.length < 2) continue;
    const ns = String(v[0]);
    const ms = Number(ns.slice(0, -6)) || 0;
    lines.push({ ts: ms ? new Date(ms).toISOString() : null, line: String(v[1]), labels: stream.stream || {} });
  }
}

const levelOf = (l) => (/(fatal|panic|critical|exception|\berror\b|\berr\b)/i.test(l) ? 'error' : /\bwarn(ing)?\b/i.test(l) ? 'warning' : 'other');
// Group similar messages: numbers, hex ids and UUIDs become placeholders.
const pattern = (l) => l
  .replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, '<uuid>')
  .replace(/\b0x[0-9a-f]+\b/gi, '<hex>')
  .replace(/\d+(\.\d+)?/g, '<n>')
  .trim()
  .slice(0, 160);

let errors = 0;
let warnings = 0;
const groups = {};
let firstError = null;
for (const l of lines) {
  const level = levelOf(l.line);
  if (level === 'error') {
    errors++;
    if (l.ts && (!firstError || l.ts < firstError)) firstError = l.ts;
  } else if (level === 'warning') warnings++;
  if (level !== 'other') {
    const p = pattern(l.line);
    groups[p] = (groups[p] || 0) + 1;
  }
}
const top = Object.entries(groups).sort((a, b) => b[1] - a[1]).slice(0, 5);

if (errors === 0 && warnings === 0) {
  return [{ json: investigationResult('logs', ctx, { status: 'no_evidence', window: req.window, summary: 'No error or warning log lines for ' + ctx.service_name + ' in the window.', findings: [], evidence: [], confidence: 0.2 }) }];
}

const findings = [
  errors + ' error and ' + warnings + ' warning log lines for ' + ctx.service_name + ' between ' + req.window.start + ' and ' + req.window.end + (lines.length >= req.limit ? ' (limit reached, more lines may exist)' : '') + '.',
];
if (firstError) findings.push('First error line at ' + firstError + '.');
for (const [p, n] of top) findings.push('Repeated message (' + n + 'x): ' + redact(p));

const evidence = lines
  .filter((l) => levelOf(l.line) !== 'other')
  .slice(0, 10)
  .map((l) => ({ type: 'log', source: 'loki', timestamp: l.ts, level: levelOf(l.line), value: redact(truncate(l.line, 300)) }));

return [{
  json: investigationResult('logs', ctx, {
    status: 'evidence_found',
    window: req.window,
    summary: errors > 0 ? 'Error activity found in ' + ctx.service_name + ' logs (' + errors + ' error lines).' : 'Only warnings found in ' + ctx.service_name + ' logs (' + warnings + ').',
    findings,
    evidence,
    confidence: errors > 0 ? 0.7 : 0.4,
  }),
}];
