// Workflow 06 – Node: "Sign start request".
//   POST /api/machine/playbook-runs/:id/start   { n8n_execution_id, workflow_name }
// Implemented in backend/src/routes/machine.routes.ts -> start_playbook_run,
// which only succeeds if the run is "approved", the playbook is enabled and an
// approved approval exists (decision A4). This is the approval check.
//#include lib/hmac.js

const d = $input.first().json;
const executionId = String($execution.id);
const req = signedBackendRequest($env, 'POST', '/api/machine/playbook-runs/' + d.playbook_run_id + '/start', {
  n8n_execution_id: executionId,
  workflow_name: 'remediation',
});
return [{ json: { ...d, n8n_execution_id: executionId, request: req } }];
