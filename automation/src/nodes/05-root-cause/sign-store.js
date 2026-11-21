// Workflow 05 – Node: "Sign store request". Builds the signed request for
//   POST /api/machine/investigations/:id/analysis
// (path and body from database/API_AND_INTEGRATION_CONTRACTS.md B.3, which maps
// to record_ai_analysis). The backend route is NOT implemented yet (BD-2), so
// today the call returns 404 and is reported as "not_implemented".
//#include lib/hmac.js

const d = $input.first().json;
const r = d.rca;
const path = '/api/machine/investigations/' + d.investigation_id + '/analysis';
const req = signedBackendRequest($env, 'POST', path, {
  incident_id: d.incident_id,
  summary: r.summary,
  root_cause: r.root_cause,
  severity: r.severity,
  confidence: r.confidence,
  evidence: r.evidence,
  recommended_action: r.recommended_action,
  model_name: d.model,
});
return [{ json: { ...d, request: req } }];
