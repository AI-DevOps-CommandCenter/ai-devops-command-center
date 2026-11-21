// Workflow 07 – Node: "Evaluate health". Input: request + Prometheus answer
// combined by position (Merge node), so it also works inside the loop.
//#include lib/common.js

const items = $input.all().map((i) => i.json);
const state = items[0].state;
const results = items.map((it) => {
  const q = it.check;
  const c = classifyHttp(it);
  if (c.kind !== 'ok') return { name: q.name, ok: false, healthy: null, error: c.kind + (c.status ? ' ' + c.status : '') };
  const b = it.body;
  if (!b || b.status !== 'success' || !b.data || !Array.isArray(b.data.result)) return { name: q.name, ok: false, healthy: null, error: 'invalid_response' };
  const vals = b.data.result.map((s) => Number(s.value && s.value[1])).filter(Number.isFinite);
  if (!vals.length) return { name: q.name, ok: false, healthy: null, error: 'no_data' };
  const v = q.name === 'error_rate' ? vals.reduce((a, x) => a + x, 0) : Math.min(...vals);
  const healthy = q.healthy_if === 'equals_1' ? v === 1 : v <= q.threshold;
  return { name: q.name, ok: true, value: v, threshold: q.threshold === undefined ? null : q.threshold, healthy };
});

const check = { attempt: state.attempt, at: new Date().toISOString(), results };
const checks = [...(state.checks || []), check];
const allMeasured = results.every((r) => r.ok);
const healthy = allMeasured && results.every((r) => r.healthy);
const unhealthy = results.some((r) => r.ok && r.healthy === false);
const last = state.attempt >= state.max_checks;

let verdict = null;
if (healthy) verdict = 'recovered';
else if (last) verdict = allMeasured || unhealthy ? 'not_recovered' : 'unable_to_verify';

return [{ json: { ...state, checks, verdict, done: verdict !== null } }];
