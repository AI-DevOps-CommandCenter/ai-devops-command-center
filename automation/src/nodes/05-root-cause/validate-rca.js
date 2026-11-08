// Workflow 05 – Node: "Validate RCA". Checks the Groq answer against
// automation/schemas/rca-output.schema.json. AI text is stored as data only;
// it is never turned into a command, and nothing here starts a remediation.
//#include lib/common.js
//#include lib/ai.js

const prev = $('Build RCA prompt').first().json;
const ctx = prev.ctx;
const response = $input.first().json;
const c = classifyHttp(response);
const base = {
  incident_id: ctx.incident_id,
  investigation_id: ctx.investigation_id,
  service_name: ctx.service_name,
  model: prev.model,
  sources: prev.source_status,
  partial_evidence: prev.partial,
  requires_human_review: true,
};

if (c.kind !== 'ok') {
  return [{ json: { ...base, valid: false, can_store: false, status: 'ai_unavailable', rca: null, error: { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message } } }];
}
const parsed = parseModelJson(response);
if (!parsed.ok) {
  return [{ json: { ...base, valid: false, can_store: false, status: 'invalid_ai_response', rca: null, error: { kind: 'invalid_response', message: parsed.error } } }];
}
const v = validateRca(parsed.value);
if (!v.ok) {
  return [{ json: { ...base, valid: false, can_store: false, status: 'invalid_ai_response', rca: null, error: { kind: 'schema_validation', message: v.errors.join('; ') } } }];
}

let blocker = null;
if (!ctx.incident_id) blocker = 'No incident_id: incidents cannot be created by n8n yet (backend dependency BD-1).';
else if (!ctx.investigation_id) blocker = 'No investigation_id: the analysis endpoint needs an investigation (backend dependency BD-2).';

return [{
  json: {
    ...base,
    valid: true,
    can_store: !blocker,
    store_blocker: blocker,
    status: 'analysis_ready',
    model: parsed.model || prev.model,
    rca: v.value,
    error: null,
  },
}];
