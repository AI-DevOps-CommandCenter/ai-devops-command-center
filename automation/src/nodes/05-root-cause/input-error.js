// Workflow 05 – Node: "RCA result (invalid input)".
const d = $input.first().json;
return [{ json: { incident_id: d.incident_id || null, valid: false, status: 'invalid_input', rca: null, stored: false, analysis_id: null, error: { kind: 'invalid_input', message: d.error } } }];
