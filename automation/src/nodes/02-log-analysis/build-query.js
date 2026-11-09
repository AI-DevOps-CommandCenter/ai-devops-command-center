// Workflow 02 – Log Analysis (owner: Tharindu)
// Node: "Build LogQL query". Validates the input and builds the Loki
// query_range request. If Loki is not configured or the input is invalid, it
// returns a ready-made result with skip=true (no HTTP call is made).
//#include lib/common.js

const env = $env;
const input = readInvestigationInput($input.first().json);
const ctx = input.ctx;

if (!input.ok) {
  return [{ json: { skip: true, result: investigationResult('logs', ctx, { status: 'invalid_input', error: { kind: 'invalid_input', message: input.error } }) } }];
}

const lokiUrl = String(env.LOKI_URL || '').replace(/\/+$/, '');
if (!/^https?:\/\//.test(lokiUrl)) {
  return [{ json: { skip: true, result: investigationResult('logs', ctx, { status: 'not_configured', summary: 'Loki is not configured (LOKI_URL).', error: { kind: 'not_configured', message: 'Set LOKI_URL in the n8n environment.' } }) } }];
}

// The label that identifies a service in Loki depends on the log shipper
// (e.g. promtail "job", docker "compose_service"). It must be confirmed with
// the monitoring owner and set in LOKI_SERVICE_LABEL.
const label = String(env.LOKI_SERVICE_LABEL || 'service');
if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(label)) throw new Error('LOKI_SERVICE_LABEL is not a valid label name.');

const before = envInt(env, 'LOKI_LOOKBACK_MINUTES', 15, 1, 360);
const after = envInt(env, 'LOKI_AFTER_MINUTES', 5, 0, 60);
const limit = envInt(env, 'LOKI_MAX_LINES', 200, 10, 2000);
const started = new Date(ctx.started_at).getTime();
const start = new Date(started - before * 60000);
const end = new Date(Math.min(Date.now(), started + after * 60000));

// service_name is validated to [A-Za-z0-9_.:-], so it cannot break out of the string.
const query = '{' + label + '="' + ctx.service_name + '"} |~ "(?i)(error|exception|fatal|panic|critical|warn)"';
const params = toQuery({
  query,
  start: start.toISOString(),
  end: end.toISOString(),
  limit: String(limit),
  direction: 'backward',
});

return [{
  json: {
    skip: false,
    ctx,
    query,
    window: { start: start.toISOString(), end: end.toISOString() },
    limit,
    url: lokiUrl + '/loki/api/v1/query_range?' + params,
    timeout_ms: envInt(env, 'LOKI_TIMEOUT_MS', 15000, 1000, 60000),
  },
}];
