// Workflow 05 – Node: "Combine evidence". Collects the results of workflows
// 02/03/04 (one item each; a failed sub-workflow arrives as { error }).
//#include lib/common.js

const ctx = $('Validate RCA input').first().json;
const expected = ['logs', 'metrics', 'deployments'];
const results = {};
for (const item of $input.all()) {
  const r = item.json || {};
  if (r.source && expected.includes(r.source)) results[r.source] = r;
}
// A sub-workflow that crashed returns { error } without a source: mark the
// missing sources as workflow failures (not as "no evidence").
const sources = expected.map((s) => results[s] || {
  source: s,
  status: 'workflow_failed',
  ok: false,
  summary: 'The ' + s + ' workflow failed or returned nothing.',
  findings: [], evidence: [], confidence: 0,
  error: { kind: 'workflow_failed', message: 'Sub-workflow error (see the n8n execution log).' },
});

const withEvidence = sources.filter((s) => s.status === 'evidence_found');
const okSources = sources.filter((s) => s.ok);
let decision;
if (withEvidence.length) decision = 'analyze';
else if (okSources.length) decision = 'no_evidence';
else decision = 'sources_unavailable';

return [{
  json: {
    ctx,
    decision,
    sources,
    source_status: sources.map((s) => ({ source: s.source, status: s.status, error: s.error ? s.error.kind : null })),
    partial: okSources.length < expected.length,
  },
}];
