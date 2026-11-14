// Workflow 06 – Node: "Check executor result".
// Reads the answer of "Executor: execute" (POST <EXECUTOR_URL>/v1/execute) and
// sets outcome + result for "Sign complete request". Contract:
// infrastructure/playbooks/executor/README.md.
//   200 { executed: true, ... }      -> success
//   200/500 with repeated: true      -> the executor's stored result for this run
//                                       (nothing ran again); success only if executed
//   500 { executed: false, message } -> failed (the action ran and failed)
//   400/401/403/409/422/503          -> failed, nothing was executed
//   timeout / connection error       -> failed; the action MAY have run (a
//                                       restart can take ~70 s), so the reason says
//                                       to check the service. Not retried here:
//                                       the run is completed as failed and the
//                                       recovery check is skipped.
// The request (headers, signature, nonce) is never copied into the result.
//#include lib/common.js

const d = $('Call executor?').first().json;
const response = $input.first().json;
const c = classifyHttp(response);
const { request, execute_via_executor, ...ctx } = d;
const ACTION = ctx.action_type;
const b = response && response.body && typeof response.body === 'object' ? response.body : {};
const text = (v, n) => (typeof v === 'string' ? redact(truncate(v, n)) : null);

const ranOk = c.kind === 'ok' && b.executed === true;
let reason = null;
if (!ranOk) {
  if (c.kind === 'timeout') reason = 'Executor did not answer in time. The action may still have run: check the service, then retry with a new run if needed.';
  else if (c.kind === 'unavailable') reason = 'Executor is not reachable: ' + c.message;
  else if (c.kind === 'ok') reason = 'Executor answered without executed: true.';
  else reason = 'Executor refused or failed (HTTP ' + c.status + '): ' + (c.message || 'no message');
}

return [{
  json: {
    ...ctx,
    outcome: ranOk ? 'success' : 'failed',
    result: {
      action: ACTION,
      executed: ranOk,
      executor: true,
      service_name: text(b.service_name, 100) || (ctx.request_payload && ctx.request_payload.service_name) || null,
      http_status: c.status,
      repeated: b.repeated === true,
      started_at: text(b.started_at, 40),
      finished_at: text(b.finished_at, 40),
      detail: text(typeof b.detail === 'string' ? b.detail : (b.detail ? JSON.stringify(b.detail) : null), 500),
      reason,
    },
  },
}];
