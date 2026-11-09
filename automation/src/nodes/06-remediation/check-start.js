// Workflow 06 – Node: "Check start result". The action that runs is the one
// the DATABASE returns for this run (start_playbook_run -> action_type), not
// the one in the webhook. A mismatch means the request is not trustworthy.
//#include lib/common.js

const d = $('Sign start request').first().json;
const response = $input.first().json;
const c = classifyHttp(response, { serviceUnavailableMeansNotConfigured: true });
const { request, ...ctx } = d;

if (c.kind !== 'ok') {
  // 409 = not approved / already started / playbook disabled (DC409);
  // 404 = run not found; 401 = signature rejected; 503 = backend machine config missing.
  const http = c.status === 409 || c.status === 404 || c.status === 400 ? c.status : 502;
  return [{ json: { ...ctx, request_payload: {}, started: false, http_status: http, response: { accepted: false, message: 'Backend refused to start the run: ' + (c.message || c.kind) } } }];
}

const data = (response.body && response.body.data) || {};
const problems = [];
if (data.status !== 'running') problems.push('run status is ' + data.status);
if (data.incident_id && data.incident_id !== ctx.incident_id) problems.push('incident_id does not match the run');
if (data.action_type !== ctx.requested_action) problems.push('action_type does not match the approved playbook (' + data.action_type + ')');

// The remediation context (e.g. service_name) is taken from the run's
// request_payload as stored in the DATABASE (returned by start_playbook_run),
// never from the webhook body. Without a valid service_name nothing is
// executed: no service is guessed, and the started run is completed as failed.
const dbPayload = data.request_payload !== null && typeof data.request_payload === 'object' && !Array.isArray(data.request_payload) ? data.request_payload : null;
if (!dbPayload) problems.push('the database returned no request_payload for the run');
else if (typeof dbPayload.service_name !== 'string' || !/^[A-Za-z0-9_.:-]{1,100}$/.test(dbPayload.service_name)) problems.push('request_payload.service_name is missing or invalid in the database run');

return [{
  json: {
    ...ctx,
    // Replaces the webhook copy: every later node reads the database copy.
    request_payload: dbPayload || {},
    started: problems.length === 0,
    started_but_rejected: problems.length > 0,
    rejection: problems.length ? problems.join('; ') : null,
    action_type: data.action_type,
    automation_run_id: data.automation_run_id || null,
    http_status: problems.length ? 409 : 202,
    response: problems.length
      ? { accepted: false, message: 'Run started but rejected: ' + problems.join('; ') + '. It will be completed as failed.' }
      : { accepted: true, playbook_run_id: ctx.playbook_run_id, action_type: data.action_type, mode: ctx.execution_mode },
  },
}];
