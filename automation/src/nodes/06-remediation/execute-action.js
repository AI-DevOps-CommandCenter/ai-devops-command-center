// Workflow 06 – Nodes: "Execute: restart / rollback / scale / circuit_breaker".
// (The same code is used in the four branches; ACTION is set by the builder.)
//
// This node never runs shell commands and never takes a command from the
// webhook or the AI. ACTION is fixed per branch; service_name comes from the
// DATABASE copy of the run (set by "Check start result").
//   REMEDIATION_EXECUTION_MODE=executor -> builds a signed POST /v1/execute for
//       the playbook executor (infrastructure/playbooks/executor, owner: Keshan)
//       with only { action, service_name, playbook_run_id }. The HTTP call is
//       made by "Executor: execute"; "Check executor result" reads the answer.
//       The executor maps service_name to a container through its own
//       allowlist.json, so nothing in the request picks a container or command.
//   REMEDIATION_EXECUTION_MODE=simulate -> records a clearly marked simulated
//       result (for end-to-end tests only)
//   anything else -> never reaches this node (the workflow refuses before
//       starting the run)
//#include lib/common.js
//#include lib/hmac.js

const env = $env;
const d = $input.first().json;
const ACTION = '__ACTION__';
if (d.action_type !== ACTION) throw new Error('Branch/action mismatch: ' + d.action_type + ' in ' + ACTION + ' branch.');

const p = d.request_payload;
const serviceName = p && typeof p.service_name === 'string' && /^[A-Za-z0-9_.:-]{1,100}$/.test(p.service_name) ? p.service_name : null;

if (d.execution_mode === 'executor') {
  if (!serviceName) {
    return [{ json: { ...d, execute_via_executor: false, outcome: 'failed', result: { action: ACTION, executed: false, reason: 'request_payload.service_name is missing or invalid; nothing was executed.' } } }];
  }
  const req = signedBackendRequest(
    { MACHINE_SIGNING_SECRET: env.EXECUTOR_SIGNING_SECRET, BACKEND_BASE_URL: env.EXECUTOR_URL },
    'POST', '/v1/execute',
    { action: ACTION, service_name: serviceName, playbook_run_id: d.playbook_run_id },
  );
  // A restart waits up to 10 s for the stop and 60 s for /health (executor README).
  req.timeout_ms = envInt(env, 'EXECUTOR_TIMEOUT_MS', 90000, 10000, 300000);
  return [{ json: { ...d, execute_via_executor: true, request: req } }];
}

if (d.execution_mode !== 'simulate') {
  return [{ json: { ...d, execute_via_executor: false, outcome: 'failed', result: { action: ACTION, executed: false, reason: 'No playbook executor is configured.' } } }];
}
return [{
  json: {
    ...d,
    execute_via_executor: false,
    outcome: 'success',
    result: {
      action: ACTION,
      executed: false,
      simulated: true,
      note: 'SIMULATED result: no real system was changed (REMEDIATION_EXECUTION_MODE=simulate).',
      service_name: serviceName,
    },
  },
}];
