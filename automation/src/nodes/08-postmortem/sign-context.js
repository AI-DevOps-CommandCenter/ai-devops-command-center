// Workflow 08 – Node: "Sign context request". Input from 07: the recovery
// result { incident_id, playbook_run_id, service_name, action_type, status, ... }.
// Builds the signed GET /api/machine/incidents/:id/context (BD-4) so the report
// uses the stored incident, AI analysis and timeline. Without an incident id
// (or signing config) the context step is skipped and only the input is used.
//#include lib/hmac.js
//#include lib/common.js

const input = $input.first().json || {};
let request = null;
let sign_error = null;
if (isUuid(input.incident_id)) {
  try {
    request = signedBackendRequest($env, 'GET', '/api/machine/incidents/' + input.incident_id + '/context');
  } catch (e) {
    sign_error = String(e.message || e);
  }
}
return [{ json: { input, request, skip_context: !request, sign_error } }];
