// Workflow 08 – Postmortem (owner: Tharindu)
// Node: "Collect incident context".
// Combines the input from 07 (recovery result) with the context stored in the
// backend (BD-4: GET /api/machine/incidents/:id/context -> incident, latest AI
// analysis, runs, recovery checks, timeline). Values passed in by the caller
// win; the backend fills what is missing. It never invents missing facts:
// missing parts are listed as "unknown".
//
// impact_facts: measured numbers for the "impact" section, computed here so
// the AI does not have to do date arithmetic (detection -> recovery duration,
// error rates measured by 07, earlier recovery checks). Null when unknown.
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

function toTime(v) {
  const t = v ? new Date(v) : null;
  return t && !isNaN(t.getTime()) ? t : null;
}

function percent(v) {
  return Math.round(Number(v) * 1000) / 10; // 0.1741 -> 17.4
}

function impactFacts() {
  const incident = j.incident || {};
  const detected = toTime(incident.detected_at || incident.created_at);
  const evidence = recovery && Array.isArray(recovery.evidence) ? recovery.evidence : [];
  const recovered = recovery && (recovery.status === 'recovered' || recovery.status === 'healthy');
  let recoveredAt = null;
  if (recovered) {
    const lastAt = evidence.map((c) => toTime(c && c.at)).filter(Boolean).pop();
    recoveredAt = lastAt || new Date();
  }
  const errorRates = [];
  for (const c of evidence) {
    const results = c && Array.isArray(c.results) ? c.results : [];
    for (const r of results) {
      if (r && r.name === 'error_rate' && r.ok && Number.isFinite(Number(r.value))) {
        errorRates.push({
          at: toTime(c.at) ? toTime(c.at).toISOString() : null,
          error_rate_percent: percent(r.value),
          threshold_percent: Number.isFinite(Number(r.threshold)) && r.threshold !== null ? percent(r.threshold) : null,
        });
      }
    }
  }
  const earlierChecks = (Array.isArray(stored.recovery_checks) ? stored.recovery_checks : [])
    .filter((c) => c && c.playbook_run_id !== j.playbook_run_id)
    .map((c) => ({ checked_at: c.checked_at || null, status: c.status || null }))
    .slice(0, 10);
  const minutes = detected && recoveredAt ? Math.max(0, Math.round((recoveredAt - detected) / 60000)) : null;
  return {
    service_name: j.service_name || incident.service_name || null,
    severity: incident.severity || null,
    alert_description: incident.description || null,
    detected_at: detected ? detected.toISOString() : null,
    recovered_at: recoveredAt ? recoveredAt.toISOString() : null,
    detection_to_recovery_minutes: minutes,
    error_rate_after_remediation: errorRates.slice(-6),
    peak_error_rate_after_remediation_percent: errorRates.length ? Math.max(...errorRates.map((e) => e.error_rate_percent)) : null,
    remediation_runs: Array.isArray(stored.playbook_runs) ? stored.playbook_runs.length : null,
    earlier_recovery_checks: earlierChecks,
  };
}

const context = {
  incident_id: j.incident_id || null,
  playbook_run_id: j.playbook_run_id || null,
  service_name: j.service_name || null,
  incident: j.incident || null,
  rca: j.rca || null,
  remediation: { action_type: j.action_type || null, simulated: !!(j.simulated || j.simulated_remediation) },
  recovery,
  impact_facts: impactFacts(),
  timeline: Array.isArray(j.timeline) ? j.timeline.slice(0, 50) : [],
};
// Enough to write a useful report: we need at least the recovery outcome or an RCA.
const enough = !!(recovery || j.rca);
return [{ json: { enough, missing, context } }];
