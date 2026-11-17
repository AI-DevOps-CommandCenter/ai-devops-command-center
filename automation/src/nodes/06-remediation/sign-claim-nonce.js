// Workflow 06 – Node: "Sign nonce claim" (KI-1 / D-N8N-6).
//   POST /api/machine/remediation-nonces  { nonce, signed_at }
// Claims the nonce of the incoming webhook request in the DATABASE
// (consume_automation_nonce), atomically and shared by all executions, before
// the run is started. The static-data check in "Verify signature and payload"
// stays as a first filter.
//#include lib/hmac.js

const d = $input.first().json;
const req = signedBackendRequest($env, 'POST', '/api/machine/remediation-nonces', {
  nonce: d.webhook_nonce,
  signed_at: d.webhook_signed_at,
});
return [{ json: { ...d, request: req } }];
