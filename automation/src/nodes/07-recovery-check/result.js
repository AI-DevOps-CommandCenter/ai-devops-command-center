// Workflow 07 – Node: "Recovery result". Output contract:
// { incident_id, playbook_run_id, status, db_status, checks_performed, evidence, ok,
//   stored, recovery_check_id, store_error, soft_failure }
//
// BD-3 integration (Vishwa, recovery-check integration): POST /api/machine/recovery-checks
// now exists in the backend (201 { data: { recovery_check_id } }). A 404 from it is
// therefore a real answer (e.g. DC404 "Incident not found."), no longer "not
// implemented", and every store failure is returned as soft_failure, so workflow 06
// notifies workflow 09. The recovery verdict itself is unchanged.
//#include lib/common.js

const signed = $('Sign recovery check request').first().json;
const response = $input.first().json;
let stored = false;
let recoveryCheckId = null;
let storeError = signed.store_error || null;
if (!signed.skip_store) {
  const c = classifyHttp(response, { serviceUnavailableMeansNotConfigured: true });
  stored = c.kind === 'ok';
  const data = stored && response.body && response.body.data ? response.body.data : null;
  recoveryCheckId = data && typeof data.recovery_check_id === 'string' ? data.recovery_check_id : null;
  storeError = stored ? null : { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message };
} else if (!storeError) {
  storeError = { kind: 'invalid_input', message: 'incident_id/playbook_run_id missing.' };
}
// Missing ids (a manual/test run without a remediation) are not an operator problem.
const softFailure = !stored && storeError && storeError.kind !== 'invalid_input' ? {
  kind: 'recovery_store_failed',
  node: 'Backend: store recovery check',
  message: 'Storing the recovery check (' + (signed.result && signed.result.db_status) + ') for playbook run ' + ((signed.result && signed.result.playbook_run_id) || '?')
    + ' failed: ' + storeError.kind + (storeError.http_status ? ' HTTP ' + storeError.http_status : '') + (storeError.message ? ' - ' + String(storeError.message).replace(/\.+$/, '') : '') + '.',
} : null;
return [{ json: { ...signed.result, stored, recovery_check_id: recoveryCheckId, store_error: storeError, soft_failure: softFailure } }];
