// ---- shared: AI (Groq) helpers ----
// Allowed values come from the database CHECK constraints
// (ai_analyses_action_allowed, ai_analyses_severity_allowed, playbooks_action_type_allowed).
const AI_ACTIONS = ['restart', 'rollback', 'scale', 'circuit_breaker'];
const AI_SEVERITIES = ['low', 'medium', 'high', 'critical'];

function groqBaseUrl(env) {
  return String(env.GROQ_API_BASE_URL || 'https://api.groq.com/openai/v1').replace(/\/+$/, '');
}

function groqModel(env) {
  const m = env.GROQ_MODEL;
  if (!m || !/^[A-Za-z0-9._:/-]{1,100}$/.test(m)) throw new Error('GROQ_MODEL is not configured.');
  return m;
}

function groqRequest(env, system, user, maxTokens) {
  return {
    model: groqModel(env),
    temperature: 0.1,
    max_tokens: maxTokens || 1200,
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
  };
}

// Extract the JSON object the model returned. Returns { ok, value, error }.
function parseModelJson(httpItem) {
  const body = httpItem && httpItem.body;
  const content = body && body.choices && body.choices[0] && body.choices[0].message && body.choices[0].message.content;
  if (typeof content !== 'string' || !content.trim()) return { ok: false, error: 'Model response has no content.' };
  let text = content.trim();
  const fence = text.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/);
  if (fence) text = fence[1];
  try {
    const value = JSON.parse(text);
    if (!value || typeof value !== 'object' || Array.isArray(value)) return { ok: false, error: 'Model response is not a JSON object.' };
    return { ok: true, value, model: body.model || null, usage: body.usage || null };
  } catch (e) {
    return { ok: false, error: 'Model response is not valid JSON.' };
  }
}

function asStringArray(v, maxItems, maxLen) {
  if (!Array.isArray(v)) return null;
  return v.filter((x) => typeof x === 'string' && x.trim()).slice(0, maxItems).map((x) => x.trim().slice(0, maxLen));
}

// Validate an RCA object (automation/schemas/rca-output.schema.json).
// Never trusts the model: unknown actions are rejected, text is length-limited,
// and the result is always marked for human review.
function validateRca(o) {
  const errors = [];
  const out = {};
  if (typeof o.summary !== 'string' || !o.summary.trim()) errors.push('summary is required');
  else out.summary = o.summary.trim().slice(0, 2000);
  if (typeof o.root_cause !== 'string' || !o.root_cause.trim()) errors.push('root_cause is required');
  else out.root_cause = o.root_cause.trim().slice(0, 2000);
  if (!AI_SEVERITIES.includes(o.severity)) errors.push('severity must be one of ' + AI_SEVERITIES.join(', '));
  else out.severity = o.severity;
  if (typeof o.confidence !== 'number' || !(o.confidence >= 0 && o.confidence <= 1)) errors.push('confidence must be a number 0..1');
  else out.confidence = Math.round(o.confidence * 100) / 100;
  for (const key of ['evidence', 'confirmed_findings', 'possible_causes']) {
    const arr = asStringArray(o[key], 20, 500);
    if (arr === null) errors.push(key + ' must be an array of strings');
    else out[key] = arr;
  }
  if (o.recommended_action === null || o.recommended_action === undefined || o.recommended_action === 'none') {
    out.recommended_action = null;
  } else if (AI_ACTIONS.includes(o.recommended_action)) {
    out.recommended_action = o.recommended_action;
  } else {
    errors.push('recommended_action must be one of ' + AI_ACTIONS.join(', ') + ' or null');
  }
  const recs = asStringArray(o.recommendations || [], 10, 500);
  out.recommendations = recs || [];
  out.requires_human_review = true;
  return { ok: errors.length === 0, value: errors.length ? null : out, errors };
}

// Validate a postmortem object (automation/schemas/postmortem-output.schema.json).
function validatePostmortem(o) {
  const errors = [];
  const out = {};
  for (const key of ['title', 'summary', 'root_cause', 'impact', 'remediation', 'recovery_result']) {
    if (typeof o[key] !== 'string' || !o[key].trim()) errors.push(key + ' is required');
    else out[key] = o[key].trim().slice(0, 4000);
  }
  for (const key of ['evidence', 'lessons_learned', 'preventive_actions']) {
    const arr = asStringArray(o[key], 20, 500);
    if (arr === null) errors.push(key + ' must be an array of strings');
    else out[key] = arr;
  }
  if (!Array.isArray(o.timeline)) errors.push('timeline must be an array');
  else {
    out.timeline = o.timeline
      .filter((t) => t && typeof t.time === 'string' && typeof t.event === 'string')
      .slice(0, 50)
      .map((t) => ({ time: t.time.slice(0, 40), event: t.event.slice(0, 500) }));
  }
  return { ok: errors.length === 0, value: errors.length ? null : out, errors };
}
// ---- end shared: AI ----
