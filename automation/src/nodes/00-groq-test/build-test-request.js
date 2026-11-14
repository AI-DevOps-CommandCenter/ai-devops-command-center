// Workflow 00 – Groq Connection Test (owner: Tharindu)
// Node: "Build test request". Prepares a tiny chat completion that must answer
// with a fixed JSON object, so the response can be validated end to end.
//#include lib/common.js
//#include lib/ai.js

const env = $env;
const request = groqRequest(
  env,
  'You are a connectivity test. Reply with ONLY this JSON object: {"status":"ok","service":"groq"}',
  'Connectivity check from the Group 33 DevOps Command Center.',
  50
);

return [{
  json: {
    url: groqBaseUrl(env) + '/chat/completions',
    timeout_ms: envInt(env, 'GROQ_TIMEOUT_MS', 30000, 1000, 120000),
    model: request.model,
    groq_request: request,
  },
}];
