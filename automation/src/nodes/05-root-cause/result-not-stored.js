// Workflow 05 – Node: "RCA result (not stored)". Invalid AI answers and
// analyses without an incident/investigation id end here.
// N-2: when the AI could not be reached (status ai_unavailable: auth, rate
// limit, timeout, 5xx), soft_failure is set so workflow 01 notifies workflow 09.
// A missing incident/investigation id (BD-1/BD-2) is expected today: no alert.
const d = $input.first().json;
const e = d.error || {};
return [{
  json: {
    ...d,
    stored: false,
    analysis_id: null,
    store_error: d.valid ? { kind: 'blocked', message: d.store_blocker } : null,
    soft_failure: d.status === 'ai_unavailable' ? {
      kind: 'ai_unavailable',
      node: 'Groq: RCA',
      message: 'The AI (Groq) could not be used for the root cause analysis of ' + (d.service_name || 'an alert') + ': '
        + (e.kind || 'error') + (e.http_status ? ' HTTP ' + e.http_status : '') + (e.message ? ' - ' + String(e.message).slice(0, 150) : '') + '.',
    } : null,
  },
}];
