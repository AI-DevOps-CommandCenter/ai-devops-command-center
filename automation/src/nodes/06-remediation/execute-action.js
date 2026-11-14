// Workflow 06 – Nodes: "Execute: restart / rollback / scale / circuit_breaker".
// (The same code is used in the four branches; ACTION is set by the builder.)
//
// BLOCKED: the project has no playbook executor yet (planned in
// infrastructure/playbooks/, Gantt tasks 30-31). This node does NOT run shell
// commands and does NOT accept commands from the webhook or the AI.
//   REMEDIATION_EXECUTION_MODE=simulate -> records a clearly marked simulated
//                                          result (for end-to-end tests only)
//   anything else                       -> never reaches this node (the workflow
//                                          refuses before starting the run)
// When the executor exists, replace this node with a signed HTTP Request to it,
// passing only { action, service_name, playbook_run_id }.

const d = $input.first().json;
const ACTION = '__ACTION__';
if (d.action_type !== ACTION) throw new Error('Branch/action mismatch: ' + d.action_type + ' in ' + ACTION + ' branch.');

if (d.execution_mode !== 'simulate') {
  return [{ json: { ...d, outcome: 'failed', result: { action: ACTION, executed: false, reason: 'No playbook executor is configured (integration BLOCKED).' } } }];
}
return [{
  json: {
    ...d,
    outcome: 'success',
    result: {
      action: ACTION,
      executed: false,
      simulated: true,
      note: 'SIMULATED result: no real system was changed (REMEDIATION_EXECUTION_MODE=simulate).',
      service_name: (d.request_payload && typeof d.request_payload.service_name === 'string') ? d.request_payload.service_name.slice(0, 100) : null,
    },
  },
}];
