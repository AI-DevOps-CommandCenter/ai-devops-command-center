// ---- shared: common helpers ----
const SECRET_PATTERNS = [
  /(authorization|api[_-]?key|token|secret|password|signature)(["'\s:=]+)([^\s"',}]+)/gi,
  /\bgsk_[A-Za-z0-9]{10,}\b/g,          // Groq keys
  /\bgh[pousr]_[A-Za-z0-9]{20,}\b/g,     // GitHub tokens
  /\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}\b/g, // JWTs
  /https:\/\/hooks\.slack\.com\/[^\s"']+/g,
  /https:\/\/discord(?:app)?\.com\/api\/webhooks\/[^\s"']+/g,
];

function redact(text) {
  let out = String(text == null ? '' : text);
  for (const re of SECRET_PATTERNS) {
    // Only the first pattern has capture groups (key + separator are kept).
    out = out.replace(re, (m, a, b) => (typeof a === 'string' && typeof b === 'string' ? a + b + '[REDACTED]' : '[REDACTED]'));
  }
  return out;
}

function truncate(text, max) {
  const s = String(text == null ? '' : text);
  return s.length > max ? s.slice(0, max - 1) + '…' : s;
}

function envInt(env, name, fallback, min, max) {
  const raw = env[name];
  const n = raw === undefined || raw === '' ? fallback : Number(raw);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.round(n)));
}

function envNumber(env, name, fallback) {
  const n = Number(env[name]);
  return env[name] === undefined || env[name] === '' || !Number.isFinite(n) ? fallback : n;
}

// Classify the output of an HTTP Request node that runs with
// "full response" + "never error" + onError=continueRegularOutput.
// kind: ok | timeout | unavailable | auth | rate_limited | not_found | not_implemented | invalid | server_error | client_error
function classifyHttp(item, opts) {
  const o = opts || {};
  if (item && item.error) {
    const msg = String(item.error.message || item.error.description || item.error || '');
    const code = String(item.error.code || '');
    if (/timeout|ETIMEDOUT|ESOCKETTIMEDOUT|ECONNABORTED/i.test(msg + code)) {
      return { kind: 'timeout', retryable: true, status: null, message: 'Request timed out.' };
    }
    return { kind: 'unavailable', retryable: true, status: null, message: redact(truncate(msg || 'Connection failed.', 300)) };
  }
  const status = Number(item && item.statusCode);
  if (!status) return { kind: 'invalid', retryable: false, status: null, message: 'No HTTP status in response.' };
  if (status >= 200 && status < 300) return { kind: 'ok', retryable: false, status, message: null };
  const bodyMsg = item.body && typeof item.body === 'object' ? (item.body.message || (item.body.error && (item.body.error.message || item.body.error))) : item.body;
  const message = redact(truncate(bodyMsg || ('HTTP ' + status), 300));
  if (status === 401 || status === 403) return { kind: 'auth', retryable: false, status, message };
  if (status === 429) return { kind: 'rate_limited', retryable: true, status, message };
  if (status === 404 && o.notFoundMeansNotImplemented) return { kind: 'not_implemented', retryable: false, status, message: 'Backend endpoint is not implemented yet (404).' };
  if (status === 404) return { kind: 'not_found', retryable: false, status, message };
  if (status === 503 && o.serviceUnavailableMeansNotConfigured) return { kind: 'not_configured', retryable: true, status, message };
  if (status >= 500) return { kind: 'server_error', retryable: true, status, message };
  return { kind: 'client_error', retryable: false, status, message };
}

// Standard investigation result (automation/schemas/investigation-output.schema.json).
function investigationResult(source, ctx, fields) {
  const f = fields || {};
  return {
    incident_id: ctx.incident_id || null,
    source,
    status: f.status,                 // evidence_found | no_evidence | unavailable | not_configured | invalid_input
    ok: f.status === 'evidence_found' || f.status === 'no_evidence',
    summary: f.summary || '',
    findings: f.findings || [],
    evidence: f.evidence || [],
    confidence: typeof f.confidence === 'number' ? Math.max(0, Math.min(1, f.confidence)) : 0,
    window: f.window || null,
    error: f.error || null,
    collected_at: new Date().toISOString(),
  };
}

// URLSearchParams is not available in the n8n task-runner sandbox (n8n 2.x).
function toQuery(params) {
  return Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== null)
    .map(([k, v]) => encodeURIComponent(k) + '=' + encodeURIComponent(String(v)))
    .join('&');
}

function isUuid(v) {
  return typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
}

// Investigation input (from workflow 01 / 05). Returns { ok, ctx, error }.
function readInvestigationInput(json) {
  const j = json || {};
  const started = j.started_at ? new Date(j.started_at) : null;
  const errors = [];
  if (!j.service_name || typeof j.service_name !== 'string' || !/^[A-Za-z0-9_.:-]{1,100}$/.test(j.service_name)) {
    errors.push('service_name is required (letters, digits, _ . : - only).');
  }
  if (!started || isNaN(started.getTime())) errors.push('started_at must be an ISO timestamp.');
  if (j.incident_id != null && !isUuid(j.incident_id)) errors.push('incident_id must be a UUID or null.');
  return {
    ok: errors.length === 0,
    error: errors.join(' ') || null,
    ctx: {
      incident_id: j.incident_id || null,
      service_name: j.service_name,
      alert_name: j.alert_name || null,
      severity: j.severity || null,
      started_at: started && !isNaN(started.getTime()) ? started.toISOString() : null,
    },
  };
}
// ---- end shared: common ----
