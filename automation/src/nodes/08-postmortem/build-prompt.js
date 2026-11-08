// Workflow 08 – Node: "Build postmortem prompt".
//#include lib/common.js
//#include lib/ai.js
//#include-text prompts/postmortem-system-prompt.txt as POSTMORTEM_SYSTEM_PROMPT

const env = $env;
const d = $input.first().json;
let user = 'Incident data (JSON). Fields that are null or listed in "missing" are unknown:\n' + JSON.stringify({ missing: d.missing, ...d.context });
if (user.length > 12000) user = user.slice(0, 12000) + '\n[truncated]';
const request = groqRequest(env, POSTMORTEM_SYSTEM_PROMPT, user, 1800);
return [{ json: { ...d, url: groqBaseUrl(env) + '/chat/completions', timeout_ms: envInt(env, 'GROQ_TIMEOUT_MS', 30000, 1000, 120000), model: request.model, groq_request: request } }];
