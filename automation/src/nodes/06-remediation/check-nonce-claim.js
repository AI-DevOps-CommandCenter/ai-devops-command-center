// Workflow 06 – Node: "Check nonce claim" (KI-1 / D-N8N-6).
//   200 -> first use of this webhook request: continue to the start
//   409 -> replay: answer 409 "Replayed request", nothing is started
//   401 -> outside the 5 minute window: answer 401
//   anything else (backend down, 5xx, 404 route missing) -> fail CLOSED with
//   503: without the database check, a replay could not be told apart.
//#include lib/common.js

const d = $('Sign nonce claim').first().json;
const response = $input.first().json;
const c = classifyHttp(response, { serviceUnavailableMeansNotConfigured: true });
const { request, ...ctx } = d;

if (c.kind === 'ok') return [{ json: { ...ctx, nonce_claimed: true } }];

const refuse = (status, message) => [{
  json: { ...ctx, nonce_claimed: false, http_status: status, response: { accepted: false, message } },
}];
if (c.status === 409) return refuse(409, 'Replayed request.');
if (c.status === 401) return refuse(401, 'Signed request is outside the 5 minute window.');
return refuse(503, 'Replay protection is not available (' + c.kind + (c.status ? ' HTTP ' + c.status : '') + '). The run was not started.');
