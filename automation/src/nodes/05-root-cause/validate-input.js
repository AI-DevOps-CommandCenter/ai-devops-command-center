// Workflow 05 – Root Cause Analysis (owner: Vishwa)
// Node: "Validate RCA input". Input (from workflow 01 or a test):
// { incident_id|null, investigation_id|null, service_name, alert_name, severity, started_at, summary }
//#include lib/common.js

const j = $input.first().json;
const input = readInvestigationInput(j);
if (j.investigation_id != null && !isUuid(j.investigation_id)) {
  input.ok = false;
  input.error = (input.error ? input.error + ' ' : '') + 'investigation_id must be a UUID or null.';
}
return [{
  json: {
    valid: input.ok,
    error: input.error,
    ...input.ctx,
    investigation_id: j.investigation_id || null,
    alert_summary: truncate(redact(j.summary || ''), 300),
  },
}];
