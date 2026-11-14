// Workflow 05 – Node: "Build RCA prompt". Keeps the prompt small and
// structured; every source keeps its status so the model can see what is missing.
//#include lib/common.js
//#include lib/ai.js
//#include-text prompts/rca-system-prompt.txt as RCA_SYSTEM_PROMPT

const env = $env;
const d = $input.first().json;
const ctx = d.ctx;
const payload = {
  alert: { name: ctx.alert_name, service: ctx.service_name, severity: ctx.severity, started_at: ctx.started_at, summary: ctx.alert_summary },
  sources: d.sources.map((s) => ({
    source: s.source,
    status: s.status,
    summary: truncate(s.summary, 300),
    findings: (s.findings || []).slice(0, 8).map((f) => truncate(f, 300)),
    evidence: (s.evidence || []).slice(0, 8),
    confidence: s.confidence,
  })),
};
let user = 'Investigation data (JSON):\n' + JSON.stringify(payload);
if (user.length > 12000) user = user.slice(0, 12000) + '\n[truncated]';

const request = groqRequest(env, RCA_SYSTEM_PROMPT, user, 1200);
return [{
  json: {
    ...d,
    url: groqBaseUrl(env) + '/chat/completions',
    timeout_ms: envInt(env, 'GROQ_TIMEOUT_MS', 30000, 1000, 120000),
    model: request.model,
    groq_request: request,
  },
}];
