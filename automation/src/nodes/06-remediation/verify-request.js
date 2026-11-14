// Workflow 06 – Remediation (owner: Vishwa)
// Node: "Verify signature and payload".
// Contract (database/API_AND_INTEGRATION_CONTRACTS.md B.3):
//   POST <n8n>/webhook/remediation, headers X-DC-Timestamp/X-DC-Nonce/X-DC-Signature
//   body { playbook_run_id, incident_id, action_type, request_payload }
// The signature covers timestamp.nonce.METHOD.path.rawBody (same as the backend).
// Nothing from this request is ever executed as a command: action_type only
// selects one of four fixed branches, and the backend's start call (next
// nodes) is the authority on whether the run is approved.
//#include lib/common.js
//#include lib/hmac.js

const env = $env;
const item = $input.first();
const j = item.json;
const reject = (status, reason) => [{ json: { valid: false, http_status: status, response: { accepted: false, message: reason } } }];

// Exact bytes the backend signed: the Webhook node keeps them (option "Raw Body").
let raw = null;
const bin = item.binary && item.binary.data;
if (bin && typeof bin.data === 'string' && bin.id === undefined) raw = Buffer.from(bin.data, 'base64').toString('utf8');
if (raw === null && bin) {
  try { raw = (await this.helpers.getBinaryDataBuffer(0, 'data')).toString('utf8'); } catch (e) { raw = null; }
}
if (raw === null) return reject(400, 'Raw request body is not available; enable "Raw Body" on the Webhook node.');

const secret = env.MACHINE_SIGNING_SECRET;
if (!secret || secret.length < 32) return reject(503, 'Remediation is not configured (signing secret missing).');

const signedPath = env.N8N_REMEDIATION_SIGNED_PATH || '/webhook/remediation';
const store = $getWorkflowStaticData('global');
store.seenNonces = store.seenNonces || {};
const check = verifySignedRequest(secret, j.headers, 'POST', signedPath, raw, store.seenNonces, Date.now());
if (!check.ok) return reject(check.status, check.reason);

let body;
try { body = JSON.parse(raw); } catch (e) { return reject(400, 'Body is not valid JSON.'); }
const ACTIONS = ['restart', 'rollback', 'scale', 'circuit_breaker'];
const problems = [];
if (!isUuid(body.playbook_run_id)) problems.push('playbook_run_id must be a UUID');
if (!isUuid(body.incident_id)) problems.push('incident_id must be a UUID');
if (!ACTIONS.includes(body.action_type)) problems.push('action_type must be one of ' + ACTIONS.join(', '));
if (body.request_payload !== undefined && (typeof body.request_payload !== 'object' || body.request_payload === null || Array.isArray(body.request_payload))) problems.push('request_payload must be an object');
const extra = Object.keys(body).filter((k) => !['playbook_run_id', 'incident_id', 'action_type', 'request_payload'].includes(k));
if (extra.length) problems.push('unexpected fields: ' + extra.join(', '));
if (problems.length) return reject(400, problems.join('; '));

// Execution mode (REMEDIATION_EXECUTION_MODE):
//   disabled (default) -> refuse with 503 before the run is started
//   simulate           -> clearly marked simulated result (tests only)
//   executor           -> signed POST /v1/execute to the playbook executor
//                         (infrastructure/playbooks/executor). If EXECUTOR_URL or
//                         EXECUTOR_SIGNING_SECRET is missing, it falls back to
//                         disabled, so a run is never started that cannot execute.
const requested = String(env.REMEDIATION_EXECUTION_MODE || 'disabled').toLowerCase();
const executorReady = /^https?:\/\/[^\s]+$/.test(String(env.EXECUTOR_URL || ''))
  && typeof env.EXECUTOR_SIGNING_SECRET === 'string' && env.EXECUTOR_SIGNING_SECRET.length >= 32;
const mode = requested === 'simulate' ? 'simulate' : (requested === 'executor' && executorReady ? 'executor' : 'disabled');
return [{
  json: {
    valid: true,
    execution_mode: mode,
    execution_available: mode !== 'disabled',
    playbook_run_id: body.playbook_run_id,
    incident_id: body.incident_id,
    requested_action: body.action_type,
    request_payload: body.request_payload || {},
  },
}];
