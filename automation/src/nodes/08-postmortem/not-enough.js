// Workflow 08 – Node: "Not enough context". No recovery result and no RCA:
// a report would be guesswork, so Groq is not called.
const d = $input.first().json;
return [{ json: { incident_id: d.context.incident_id, valid: false, status: 'insufficient_context', postmortem: null, stored: false, missing_context: d.missing, error: { kind: 'insufficient_context', message: 'Need at least a recovery result or an RCA.' } } }];
