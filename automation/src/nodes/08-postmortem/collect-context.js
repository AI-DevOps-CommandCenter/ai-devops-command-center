// Workflow 08 – Postmortem (owner: Tharindu)
// Node: "Collect incident context".
// Combines the input from 07 (recovery result) with the context stored in the
// backend (BD-4: GET /api/machine/incidents/:id/context -> incident, latest AI
// analysis, runs, recovery checks, timeline). Values passed in by the caller
// win; the backend fills what is missing. It never invents missing facts:
// missing parts are listed as "unknown".
//#include lib/common.js

const signed = $('Sign context request').first().json;
const answer = signed.skip_context ? null : $input.first().json;
const stored = answer && classifyHttp(answer).kind === 'ok' && answer.body && answer.body.data ? answer.body.data : {};
const j = { ...signed.input };
if (!j.incident && stored.incident) j.incident = stored.incident;
if (!j.rca && stored.rca) j.rca = stored.rca;
if (!Array.isArray(j.timeline) && Array.isArray(stored.timeline)) j.timeline = stored.timeline;
if (!j.service_name && stored.incident) j.service_name = stored.incident.service_name || null;

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
