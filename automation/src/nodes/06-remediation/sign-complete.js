// Workflow 06 – Node: "Sign complete request".
//   POST /api/machine/playbook-runs/:id/complete
//   { n8n_execution_id, status: "success"|"failed", result }
// Must use the same n8n_execution_id that started the run (else DC403).
//
// N-1 (retry-safe completion): this node runs for the first attempt (input from
// an "Execute: …" or "Unsupported or rejected action" node) and again for every
// retry (input from "Wait before completion retry", i.e. the output of "Check
// completion"). It signs every attempt again, so each attempt has a NEW nonce
// and timestamp. The body (status and result) is the same on every attempt.
//#include lib/hmac.js

const d = $input.first().json;
const previous = Number.isInteger(d.complete_attempts) && d.complete_attempts > 0 ? d.complete_attempts : 0;
const { retry_complete, wait_seconds, complete_attempts, ...ctx } = d;
const req = signedBackendRequest($env, 'POST', '/api/machine/playbook-runs/' + ctx.playbook_run_id + '/complete', {
  n8n_execution_id: ctx.n8n_execution_id,
  status: ctx.outcome === 'success' ? 'success' : 'failed',
  result: ctx.result,
});
return [{
  json: {
    ...ctx,
    complete_attempt: previous + 1,
    complete_history: Array.isArray(ctx.complete_history) ? ctx.complete_history : [],
    request: req,
  },
}];
