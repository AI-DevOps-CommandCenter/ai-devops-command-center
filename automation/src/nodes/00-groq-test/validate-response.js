// Workflow 00 – Node: "Validate Groq response".
// Turns the raw HTTP result into a clear PASS/FAIL with a beginner-friendly hint.
//#include lib/common.js
//#include lib/ai.js

const response = $input.first().json;
const model = $('Build test request').first().json.model;
const c = classifyHttp(response);

const HINTS = {
  auth: 'Groq rejected the API key. Open n8n > Credentials > "Groq API" and check the header value is "Bearer <your key>".',
  rate_limited: 'Groq rate limit reached (HTTP 429). Wait a minute and run the test again.',
  timeout: 'Groq did not answer in time. Check the internet connection or raise GROQ_TIMEOUT_MS.',
  unavailable: 'Could not reach Groq. Check the internet connection and GROQ_API_BASE_URL.',
  not_found: 'Groq returned 404. Check GROQ_API_BASE_URL and that GROQ_MODEL exists.',
  client_error: 'Groq rejected the request. Check that GROQ_MODEL is a valid, active Groq model.',
  server_error: 'Groq had a server error. Try again later.',
  invalid: 'Unexpected response from the HTTP node.',
};

if (c.kind !== 'ok') {
  return [{ json: { ok: false, failure: c.kind, retryable: c.retryable, http_status: c.status, model, message: c.message, hint: HINTS[c.kind] || '' } }];
}

const parsed = parseModelJson(response);
if (!parsed.ok) {
  return [{ json: { ok: false, failure: 'invalid_response', retryable: true, http_status: c.status, model, message: parsed.error, hint: 'The model answered, but not with the expected JSON.' } }];
}
if (parsed.value.status !== 'ok') {
  return [{ json: { ok: false, failure: 'invalid_response', retryable: true, http_status: c.status, model, message: 'Model JSON did not contain status "ok".', hint: '' } }];
}

return [{ json: { ok: true, failure: null, http_status: c.status, model: parsed.model || model, usage: parsed.usage, message: 'Groq connection works and returns valid JSON.' } }];
