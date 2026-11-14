// Workflow 05 – Node: "RCA result (store attempted)".
// N-2: a store failure is returned as soft_failure (workflow 01 reports it to
// workflow 09). "not_implemented" (404: the BD-2 route does not exist yet) is
// expected today and stays silent.
//#include lib/common.js

const d = $('Sign store request').first().json;
const response = $input.first().json;
const c = classifyHttp(response, { notFoundMeansNotImplemented: true, serviceUnavailableMeansNotConfigured: true });
const { request, ...rest } = d;
const analysisId = c.kind === 'ok' && response.body && response.body.data ? (response.body.data.analysis_id || response.body.data.id || null) : null;
const failed = c.kind !== 'ok' && c.kind !== 'not_implemented';
return [{
  json: {
    ...rest,
    stored: c.kind === 'ok',
    analysis_id: analysisId,
    store_error: c.kind === 'ok' ? null : { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message },
    soft_failure: failed ? {
      kind: 'rca_store_failed',
      node: 'Backend: store AI analysis',
      message: 'Storing the AI analysis for incident ' + (rest.incident_id || '?') + ' failed: ' + c.kind + (c.status ? ' HTTP ' + c.status : '') + (c.message ? ' - ' + String(c.message).replace(/\.+$/, '') : '') + '.',
    } : null,
  },
}];
