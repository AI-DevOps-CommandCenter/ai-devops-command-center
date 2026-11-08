// Workflow 05 – Node: "RCA result (no AI call)". Used when no source found
// evidence ("no_evidence") or every source failed ("sources_unavailable").
// The AI is not called, so it cannot invent a cause from nothing.
const d = $input.first().json;
const ctx = d.ctx;
return [{
  json: {
    incident_id: ctx.incident_id,
    investigation_id: ctx.investigation_id,
    service_name: ctx.service_name,
    valid: false,
    status: d.decision,
    sources: d.source_status,
    partial_evidence: d.partial,
    rca: null,
    requires_human_review: true,
    stored: false,
    analysis_id: null,
    error: d.decision === 'sources_unavailable' ? { kind: 'sources_unavailable', message: 'All evidence sources failed; no investigation result.' } : null,
  },
}];
