// Workflow 05 – Node: "RCA result (not stored)". Invalid AI answers and
// analyses without an incident/investigation id end here.
const d = $input.first().json;
return [{ json: { ...d, stored: false, analysis_id: null, store_error: d.valid ? { kind: 'blocked', message: d.store_blocker } : null } }];
