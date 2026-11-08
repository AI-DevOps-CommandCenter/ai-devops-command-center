// Workflow 05 – Node: "RCA result (store attempted)".
//#include lib/common.js

const d = $('Sign store request').first().json;
const response = $input.first().json;
const c = classifyHttp(response, { notFoundMeansNotImplemented: true, serviceUnavailableMeansNotConfigured: true });
const { request, ...rest } = d;
const analysisId = c.kind === 'ok' && response.body && response.body.data ? (response.body.data.analysis_id || response.body.data.id || null) : null;
return [{
  json: {
    ...rest,
    stored: c.kind === 'ok',
    analysis_id: analysisId,
    store_error: c.kind === 'ok' ? null : { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message },
  },
}];
