// Workflow 06 – Node: "Sign complete request".
//   POST /api/machine/playbook-runs/:id/complete
//   { n8n_execution_id, status: "success"|"failed", result }
// Must use the same n8n_execution_id that started the run (else DC403).
//#include lib/hmac.js

const d = $input.first().json;
const req = signedBackendRequest($env, 'POST', '/api/machine/playbook-runs/' + d.playbook_run_id + '/complete', {
  n8n_execution_id: d.n8n_execution_id,
  status: d.outcome === 'success' ? 'success' : 'failed',
  result: d.result,
});
return [{ json: { ...d, request: req } }];
