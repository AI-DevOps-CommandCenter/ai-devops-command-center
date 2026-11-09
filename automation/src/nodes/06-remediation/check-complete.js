// Workflow 06 – Node: "Check completion". Builds the input for the recovery
// check (workflow 07). Recovery is only checked after a reported success.
//#include lib/common.js

const d = $('Sign complete request').first().json;
const response = $input.first().json;
const c = classifyHttp(response);
const { request, ...ctx } = d;
const completed = c.kind === 'ok';
// ctx.request_payload is the DATABASE copy (set by "Check start result"); the
// webhook body is never used here. An invalid or missing value stays null, so
// 07 answers unable_to_verify instead of checking a guessed service.
const p = ctx.request_payload;
const serviceName = p && typeof p.service_name === 'string' && /^[A-Za-z0-9_.:-]{1,100}$/.test(p.service_name) ? p.service_name : null;
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
