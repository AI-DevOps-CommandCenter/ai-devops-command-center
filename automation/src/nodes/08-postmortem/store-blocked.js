// Workflow 08 – Node: "Store postmortem (backend) – BLOCKED".
// There is no machine endpoint to save a postmortem yet (BD-4), so the draft
// is returned in the execution output only. When the endpoint exists, replace
// this node with "Sign request" + "HTTP Request" (pattern: workflow 07).
const d = $input.first().json;
return [{ json: { ...d, stored: false, store_error: d.valid ? { kind: 'blocked', message: 'No backend endpoint for saving postmortems yet (backend dependency BD-4).' } : null } }];
