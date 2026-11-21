// Safe handling of HTTP responses for the n8n integration test (I-7).
// Pure functions: no network, no n8n. Unit-tested in tests/integration-response.test.mjs.

// Parses a response body. Never throws: invalid JSON keeps the raw text, an
// empty body becomes undefined.
export function parseBody(text) {
  if (typeof text !== 'string' || text.trim() === '') return undefined;
  try { return JSON.parse(text); } catch { return text; }
}

// A harness webhook is ready only when n8n answers it with 2xx. 404 means the
// webhook is not registered yet; 503 ("Database is not ready") and every other
// 4xx/5xx or a missing response (connection refused) mean "not ready".
export function isWebhookReady(probe) {
  const status = probe && Number(probe.status);
  return Number.isInteger(status) && status >= 200 && status < 300;
}

const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

// One field of a JSON object body, or undefined when the body is missing,
// null, not JSON, an array or another unexpected shape.
export function jsonField(r, key) {
  return r && isObject(r.json) ? r.json[key] : undefined;
}

// The "message" of a JSON body as a string ('' when there is none).
export function messageOf(r) {
  const m = jsonField(r, 'message');
  return typeof m === 'string' ? m : '';
}

// JSON text of any value (undefined -> ''), so .includes() never crashes.
export function jsonText(value) {
  const t = JSON.stringify(value);
  return typeof t === 'string' ? t : '';
}

// Short, safe description of a probe for a failure message.
export function describeProbe(probe) {
  if (!probe) return 'no response (connection failed)';
  return 'HTTP ' + probe.status + (probe.message ? ' ' + String(probe.message).slice(0, 200) : '');
}
