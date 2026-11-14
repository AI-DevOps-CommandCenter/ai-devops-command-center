// Workflow 08 – Node: "Validate postmortem". Checks the Groq answer against
// automation/schemas/postmortem-output.schema.json.
//#include lib/common.js
//#include lib/ai.js

const prev = $('Build postmortem prompt').first().json;
const response = $input.first().json;
const c = classifyHttp(response);
const base = { incident_id: prev.context.incident_id, playbook_run_id: prev.context.playbook_run_id, model: prev.model, missing_context: prev.missing };
if (c.kind !== 'ok') return [{ json: { ...base, valid: false, status: 'ai_unavailable', postmortem: null, error: { kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message } } }];
const parsed = parseModelJson(response);
if (!parsed.ok) return [{ json: { ...base, valid: false, status: 'invalid_ai_response', postmortem: null, error: { kind: 'invalid_response', message: parsed.error } } }];
const v = validatePostmortem(parsed.value);
if (!v.ok) return [{ json: { ...base, valid: false, status: 'invalid_ai_response', postmortem: null, error: { kind: 'schema_validation', message: v.errors.join('; ') } } }];
return [{ json: { ...base, valid: true, status: 'draft_ready', postmortem: v.value, error: null } }];
