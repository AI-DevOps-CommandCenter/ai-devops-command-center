// Workflow 06 – Node: "Check completion". Decides what happens after a
// completion attempt, and builds the input for the recovery check (workflow 07).
// Recovery is only checked after a reported success.
//
// N-1 (retry-safe completion):
//  - retried: timeout, connection error, HTTP 5xx (the request may not have
//    reached the database). At most COMPLETE_MAX_ATTEMPTS (3) attempts in total,
//    waiting COMPLETE_RETRY_BASE_SECONDS x 2^(attempt-1) between them (2 s, 4 s).
//    Every retry is signed again (new nonce) by "Sign complete request".
//  - never retried: every HTTP 4xx (400 invalid, 401 signature, 403 execution id,
//    404 run not found, 409 run not running, 429 rate limited).
//  - complete_playbook_run locks the run and refuses a run that is not "running"
//    (DC409 "The run is <status>, not running."), so a retry can never complete a
//    run twice. If an EARLIER attempt was ambiguous (timeout/connection/5xx) and a
//    later one gets 409 with exactly the status we sent, the earlier attempt
//    reached the database: the run is reported as completed (completion_confirmed_by
//    "run_state"), not as failed.
//  - after the last failed attempt, soft_failure is set (redacted, no request data)
//    and workflow 06 notifies workflow 09.
//#include lib/common.js

const env = $env;
const d = $('Sign complete request').first().json;
const response = $input.first().json;
const c = classifyHttp(response);
const { request, ...ctx } = d;

const MAX_ATTEMPTS = 3;
const AMBIGUOUS = ['timeout', 'unavailable', 'server_error'];
const attempt = Number.isInteger(ctx.complete_attempt) && ctx.complete_attempt > 0 ? ctx.complete_attempt : 1;
const sentStatus = ctx.outcome === 'success' ? 'success' : 'failed';
const history = (Array.isArray(ctx.complete_history) ? ctx.complete_history : [])
  .concat([{ attempt, kind: c.kind, http_status: c.status }])
  .slice(-MAX_ATTEMPTS);

const earlierAmbiguous = history.slice(0, -1).some((h) => AMBIGUOUS.includes(h.kind));
const stateMatch = c.status === 409 && /^The run is (success|failed), not running\.$/.exec(String(c.message || ''));
const confirmedByState = earlierAmbiguous && !!stateMatch && stateMatch[1] === sentStatus;
const completed = c.kind === 'ok' || confirmedByState;

// Retry (new signature) while attempts are left.
if (!completed && AMBIGUOUS.includes(c.kind) && attempt < MAX_ATTEMPTS) {
  const base = envInt(env, 'COMPLETE_RETRY_BASE_SECONDS', 2, 1, 30);
  return [{
    json: {
      ...ctx,
      complete_attempt: undefined,
      complete_attempts: attempt,
      complete_history: history,
      retry_complete: true,
      wait_seconds: base * Math.pow(2, attempt - 1),
    },
  }];
}

// ctx.request_payload is the DATABASE copy (set by "Check start result"); the
// webhook body is never used here. An invalid or missing value stays null, so
// 07 answers unable_to_verify instead of checking a guessed service.
const p = ctx.request_payload;
const serviceName = p && typeof p.service_name === 'string' && /^[A-Za-z0-9_.:-]{1,100}$/.test(p.service_name) ? p.service_name : null;
const completeError = completed ? null : {
  kind: c.kind,
  http_status: c.status,
  retryable: c.retryable,
  message: c.message,
  attempts: attempt,
};
return [{
  json: {
    incident_id: ctx.incident_id,
    playbook_run_id: ctx.playbook_run_id,
    action_type: ctx.action_type,
    outcome: ctx.outcome,
    simulated: !!(ctx.result && ctx.result.simulated),
    completed,
    completion_confirmed_by: completed ? (c.kind === 'ok' ? 'response' : 'run_state') : null,
    complete_attempts: attempt,
    complete_history: history,
    retry_complete: false,
    complete_error: completeError,
    check_recovery: completed && ctx.outcome === 'success',
    service_name: serviceName,
    soft_failure: completed ? null : {
      kind: 'completion_failed',
      node: 'Backend: complete run',
      message: 'Completing playbook run ' + ctx.playbook_run_id + ' (status ' + sentStatus + ') failed after ' + attempt
        + ' attempt(s): ' + c.kind + (c.status ? ' HTTP ' + c.status : '') + (c.message ? ' - ' + String(c.message).replace(/\.+$/, '') : '')
        + '. The run may still be "running": check it, then complete or cancel it manually.',
    },
  },
}];
