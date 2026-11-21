// Workflow 01 – Alert Intake (owner: Vishwa)
// Node: "Parse and validate alerts". Reads an Alertmanager webhook payload
// (version 4 format: { status, alerts: [{ status, labels, annotations,
// startsAt, fingerprint, ... }], ... }) and normalizes every FIRING alert.
// Resolved alerts are acknowledged but do not create incidents.
//#include lib/common.js

const env = $env;
const body = $input.first().json.body;
const errors = [];

if (!body || typeof body !== 'object' || Array.isArray(body)) errors.push('Body must be a JSON object.');
else if (!Array.isArray(body.alerts) || body.alerts.length === 0) errors.push('alerts[] is required and must not be empty.');
else if (body.alerts.length > 50) errors.push('Too many alerts in one notification (max 50).');

if (errors.length) {
  return [{ json: { valid: false, http_status: 400, response: { accepted: false, errors } } }];
}

// Which alert label names the service: configurable, then common fallbacks.
const serviceLabels = [env.ALERT_SERVICE_LABEL || 'service', 'service_name', 'job', 'app'];
// Alertmanager severities -> incidents.severity (critical|high|medium|low|info).
const SEVERITY = { critical: 'critical', page: 'critical', high: 'high', error: 'high', warning: 'medium', warn: 'medium', medium: 'medium', low: 'low', info: 'info', none: 'info' };

const alerts = [];
const rejected = [];
let resolved = 0;
body.alerts.forEach((a, i) => {
  const labels = (a && a.labels) || {};
  const ann = (a && a.annotations) || {};
  const problems = [];
  if (!labels.alertname) problems.push('labels.alertname missing');
  const service = serviceLabels.map((l) => labels[l]).find((v) => typeof v === 'string' && v);
  if (!service) problems.push('no service label (' + serviceLabels.join('/') + ')');
  else if (!/^[A-Za-z0-9_.:-]{1,100}$/.test(service)) problems.push('service label has invalid characters');
  const startsAt = a && a.startsAt ? new Date(a.startsAt) : null;
  if (!startsAt || isNaN(startsAt.getTime())) problems.push('startsAt is not a valid timestamp');
  if (problems.length) { rejected.push({ index: i, problems }); return; }
  if (a.status === 'resolved') { resolved++; return; }

  const rawSeverity = String(labels.severity || '').toLowerCase();
  alerts.push({
    fingerprint: typeof a.fingerprint === 'string' && /^[A-Za-z0-9]{1,64}$/.test(a.fingerprint) ? a.fingerprint : null,
    alert_name: truncate(labels.alertname, 100),
    service_name: service,
    severity: SEVERITY[rawSeverity] || 'medium',
    alert_severity: rawSeverity || null,
    started_at: startsAt.toISOString(),
    summary: truncate(redact(ann.summary || ann.description || labels.alertname), 300),
    description: truncate(redact(ann.description || ''), 1000),
    labels: Object.fromEntries(Object.entries(labels).slice(0, 30).map(([k, v]) => [truncate(k, 60), truncate(redact(v), 200)])),
    generator_url: typeof a.generatorURL === 'string' ? truncate(a.generatorURL, 500) : null,
  });
});

if (!alerts.length && !resolved) {
  return [{ json: { valid: false, http_status: 400, response: { accepted: false, errors: ['No valid alerts.'], rejected } } }];
}
return [{ json: { valid: true, alerts, rejected, resolved, receiver: body.receiver || null, group_key: truncate(body.groupKey || '', 300) } }];
