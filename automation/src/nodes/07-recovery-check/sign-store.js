// Workflow 07 – Node: "Sign recovery check request".
//   POST /api/machine/recovery-checks
//   { incident_id, playbook_run_id, status, check_type, details }
// (contract B.3 -> record_recovery_check). Implemented in the backend (BD-3,
// backend/src/routes/machine.routes.ts): 201 { data: { recovery_check_id } }.
// Verdict -> recovery_checks.status: recovered=healthy, not_recovered=unhealthy,
// unable_to_verify=failed (the check itself could not be completed).
//#include lib/hmac.js

const d = $input.first().json;
const STATUS = { recovered: 'healthy', not_recovered: 'unhealthy', unable_to_verify: 'failed' };
const result = {
  incident_id: d.incident_id,
  playbook_run_id: d.playbook_run_id,
  service_name: d.service_name || null,
  action_type: d.action_type || null,
  status: d.verdict,
  db_status: STATUS[d.verdict] || 'failed',
  checks_performed: (d.checks || []).length,
  evidence: (d.checks || []).slice(-3),
  reason: d.reason || null,
  simulated_remediation: !!d.simulated,
  ok: d.verdict === 'recovered',
};

if (!d.incident_id || !d.playbook_run_id) {
  return [{ json: { result, skip_store: true, request: null } }];
}
let request = null;
try {
  request = signedBackendRequest($env, 'POST', '/api/machine/recovery-checks', {
    incident_id: d.incident_id,
    playbook_run_id: d.playbook_run_id,
    status: result.db_status,
    check_type: 'prometheus',
    details: { verdict: d.verdict, checks: result.evidence, reason: result.reason, simulated_remediation: result.simulated_remediation },
  });
} catch (e) {
  return [{ json: { result, skip_store: true, request: null, store_error: { kind: 'not_configured', message: e.message } } }];
}
return [{ json: { result, skip_store: false, request } }];
