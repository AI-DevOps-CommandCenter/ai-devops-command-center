// Workflow 08 – Node: "Postmortem result". Returned to 07 (status, stored, postmortem).
//#include lib/common.js

const d = $('Sign store postmortem request').first().json;
const { request, skip_store, ...rest } = d;
if (skip_store) {
  return [{ json: { ...rest, stored: false, postmortem_id: null, store_error: rest.store_error || null } }];
}
const response = $input.first().json;
const c = classifyHttp(response);
const id = c.kind === 'ok' && response.body && response.body.data ? response.body.data.postmortem_id || null : null;
return [{
  json: {
    ...rest,
    stored: c.kind === 'ok',
    postmortem_id: id,
    store_error: c.kind === 'ok' ? null : { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message },
  },
}];
