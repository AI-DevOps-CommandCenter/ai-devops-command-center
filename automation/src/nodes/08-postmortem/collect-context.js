// Workflow 08 – Postmortem (owner: Tharindu)
// Node: "Collect incident context".
//
// BLOCKED (BD-4): the backend has no machine endpoint to READ an incident, its
// AI analysis, playbook run or recovery checks, and none to STORE a postmortem.
// So this workflow uses only the context its caller passes in:
// { incident_id, playbook_run_id, service_name, action_type, recovery: {...},
//   rca: {...}|null, incident: {...}|null, timeline: [...]|null }
// It never invents missing facts: missing parts are listed as "unknown".
//#include lib/common.js

const j = $input.first().json;
const missing = [];
if (!j.incident_id) missing.push('incident_id');
if (!j.rca) missing.push('rca (AI analysis)');
if (!j.recovery && !j.status) missing.push('recovery result');
if (!j.incident) missing.push('incident details');
const recovery = j.recovery || (j.status ? { status: j.status, checks_performed: j.checks_performed, evidence: j.evidence } : null);

const context = {
  incident_id: j.incident_id || null,
  playbook_run_id: j.playbook_run_id || null,
  service_name: j.service_name || null,
  incident: j.incident || null,
  rca: j.rca || null,
  remediation: { action_type: j.action_type || null, simulated: !!(j.simulated || j.simulated_remediation) },
  recovery,
  timeline: Array.isArray(j.timeline) ? j.timeline.slice(0, 50) : [],
};
// Enough to write a useful report: we need at least the recovery outcome or an RCA.
const enough = !!(recovery || j.rca);
return [{ json: { enough, missing, context } }];
