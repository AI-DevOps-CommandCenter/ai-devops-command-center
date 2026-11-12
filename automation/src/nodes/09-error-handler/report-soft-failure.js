// Shared Code node "Report soft failure" (N-2), used in the top-level workflows
// 01 and 06. A soft failure is a problem that does not crash the workflow (the
// workflow answers normally) but needs an operator: a completion that failed
// after all retries, an unconfirmed start, an AI that is unavailable, a result
// that could not be stored. Crashes still reach workflow 09 via "Error workflow".
//
// Input: items with { soft_failure: { kind, node, message } } (other items are ignored).
// Output: one item per distinct kind (so 3 alerts with the AI down = ONE
// notification), shaped like the Error Trigger output that workflow 09 reads:
// { execution: { id, mode, lastNodeExecuted, error: { message, node } }, workflow: { id, name } }
// Only the short, redacted message leaves this node: no request, headers,
// signature, payload or URL.
//#include lib/common.js

const groups = new Map();
for (const item of $input.all()) {
  const f = item.json && item.json.soft_failure;
  if (!f || typeof f !== 'object') continue;
  const kind = /^[a-z0-9_]{1,60}$/.test(String(f.kind)) ? String(f.kind) : 'soft_failure';
  const g = groups.get(kind) || { kind, node: typeof f.node === 'string' ? truncate(f.node, 100) : null, messages: [], count: 0 };
  g.count += 1;
  const m = redact(truncate(f.message || kind, 250));
  if (g.messages.length < 3 && !g.messages.includes(m)) g.messages.push(m);
  groups.set(kind, g);
}

const wf = typeof $workflow === 'object' && $workflow ? $workflow : {};
return [...groups.values()].map((g) => ({
  json: {
    execution: {
      id: String($execution.id),
      mode: 'soft_failure',
      lastNodeExecuted: g.node,
      error: {
        message: truncate('soft failure ' + g.kind + (g.count > 1 ? ' (' + g.count + ' items)' : '') + ': ' + g.messages.join(' | '), 300),
        node: g.node ? { name: g.node } : null,
      },
    },
    workflow: { id: wf.id || null, name: wf.name || 'unknown' },
    soft_failure: { kind: g.kind, count: g.count },
  },
}));
