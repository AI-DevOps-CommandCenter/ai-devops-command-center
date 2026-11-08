// Workflow 06 – Node: "Check completion". Builds the input for the recovery
// check (workflow 07). Recovery is only checked after a reported success.
//#include lib/common.js

const d = $('Sign complete request').first().json;
const response = $input.first().json;
const c = classifyHttp(response);
const { request, ...ctx } = d;
const completed = c.kind === 'ok';
const serviceName = ctx.result && ctx.result.service_name
  ? ctx.result.service_name
  : (ctx.request_payload && typeof ctx.request_payload.service_name === 'string' ? ctx.request_payload.service_name : null);
return [{
  json: {
    incident_id: ctx.incident_id,
    playbook_run_id: ctx.playbook_run_id,
    action_type: ctx.action_type,
    outcome: ctx.outcome,
    simulated: !!(ctx.result && ctx.result.simulated),
    completed,
    complete_error: completed ? null : { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message },
    check_recovery: completed && ctx.outcome === 'success',
    service_name: serviceName,
  },
}];
