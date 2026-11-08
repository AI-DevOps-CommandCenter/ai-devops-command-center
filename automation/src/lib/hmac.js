// ---- shared: HMAC signing (same scheme as backend/src/middleware/machine-auth.ts) ----
// canonical = timestamp + "." + nonce + "." + METHOD + "." + path + "." + rawBody
// header X-DC-Signature = "sha256=" + hex(HMAC-SHA256(secret, canonical))
const __crypto = require('crypto');
const HMAC_MAX_SKEW_SECONDS = 300;
const HMAC_MIN_SECRET_LENGTH = 32;
const HMAC_NONCE_PATTERN = /^[A-Za-z0-9_-]{16,200}$/;
const HMAC_SIGNATURE_PATTERN = /^sha256=[0-9a-f]{64}$/;

function hmacCanonical(timestamp, nonce, method, path, body) {
  return [String(timestamp), nonce, String(method).toUpperCase(), path, body].join('.');
}

function hmacSignature(secret, timestamp, nonce, method, path, body) {
  return 'sha256=' + __crypto.createHmac('sha256', secret)
    .update(hmacCanonical(timestamp, nonce, method, path, body), 'utf8').digest('hex');
}

function hmacSecret(value) {
  if (typeof value !== 'string' || value.length < HMAC_MIN_SECRET_LENGTH) {
    throw new Error('MACHINE_SIGNING_SECRET is missing or shorter than 32 characters.');
  }
  return value;
}

function hmacNonce() {
  return __crypto.randomBytes(24).toString('base64url');
}

// Build a signed backend request. `path` must be the full request path (e.g.
// /api/machine/playbook-runs/<id>/start) because the backend signs req.originalUrl.
function signedBackendRequest(env, method, path, payload, now) {
  const secret = hmacSecret(env.MACHINE_SIGNING_SECRET);
  const base = String(env.BACKEND_BASE_URL || '').replace(/\/+$/, '');
  if (!/^https?:\/\//.test(base)) throw new Error('BACKEND_BASE_URL is not configured.');
  const body = payload === undefined ? '' : JSON.stringify(payload);
  const timestamp = Math.floor((now || Date.now()) / 1000);
  const nonce = hmacNonce();
  return {
    method: method.toUpperCase(),
    url: base + path,
    path,
    body,
    headers: {
      'X-DC-Timestamp': String(timestamp),
      'X-DC-Nonce': nonce,
      'X-DC-Signature': hmacSignature(secret, timestamp, nonce, method, path, body),
    },
  };
}

// Verify an incoming signed request (backend -> n8n). Returns { ok, status, reason }.
// `seen` is a plain object used as the replay store (workflow static data).
function verifySignedRequest(secret, headers, method, path, rawBody, seen, nowMs) {
  const now = nowMs || Date.now();
  const h = {};
  for (const [k, v] of Object.entries(headers || {})) h[String(k).toLowerCase()] = v;
  const ts = h['x-dc-timestamp'];
  const nonce = h['x-dc-nonce'];
  const sig = h['x-dc-signature'];
  if (!ts || !nonce || !sig) return { ok: false, status: 401, reason: 'Signed request headers are required.' };
  if (!/^\d{1,12}$/.test(String(ts))) return { ok: false, status: 401, reason: 'Invalid request timestamp.' };
  if (Math.abs(now / 1000 - Number(ts)) > HMAC_MAX_SKEW_SECONDS) {
    return { ok: false, status: 401, reason: 'Signed request is outside the 5 minute window.' };
  }
  if (!HMAC_NONCE_PATTERN.test(nonce) || !HMAC_SIGNATURE_PATTERN.test(sig)) {
    return { ok: false, status: 401, reason: 'Invalid request signature.' };
  }
  const expected = Buffer.from(hmacSignature(hmacSecret(secret), Number(ts), nonce, method, path, rawBody), 'utf8');
  const given = Buffer.from(sig, 'utf8');
  if (given.length !== expected.length || !__crypto.timingSafeEqual(given, expected)) {
    return { ok: false, status: 401, reason: 'Invalid request signature.' };
  }
  // Replay protection: each nonce once within 15 minutes (3x the skew window).
  const cutoff = now - 15 * 60 * 1000;
  for (const [k, at] of Object.entries(seen)) if (at < cutoff) delete seen[k];
  if (seen[nonce]) return { ok: false, status: 409, reason: 'Replayed request.' };
  seen[nonce] = now;
  return { ok: true, status: 200, reason: null };
}
// ---- end shared: HMAC ----
