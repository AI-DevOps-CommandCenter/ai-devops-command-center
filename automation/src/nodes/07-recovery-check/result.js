// Workflow 07 – Node: "Recovery result". Output contract:
// { incident_id, playbook_run_id, status, db_status, checks_performed, evidence, ok, stored, store_error }
//#include lib/common.js

const signed = $('Sign recovery check request').first().json;
let stored = false;
let storeError = signed.store_error || null;
if (!signed.skip_store) {
  const c = classifyHttp($input.first().json, { notFoundMeansNotImplemented: true, serviceUnavailableMeansNotConfigured: true });
  stored = c.kind === 'ok';
  storeError = stored ? null : { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message };
} else if (!storeError) {
  storeError = { kind: 'invalid_input', message: 'incident_id/playbook_run_id missing.' };
}
return [{ json: { ...signed.result, stored, store_error: storeError } }];
