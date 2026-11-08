// Workflow 04 – Node: "Correlate changes". A change is "suspect" when it
// happened within DEPLOY_SUSPECT_MINUTES (default 60) before the incident.
// Workflow runs whose name matches DEPLOY_WORKFLOW_PATTERN (default
// deploy|release|cd) are treated as deployments.
//#include lib/common.js

const env = $env;
const reqs = $('Build GitHub requests').all().map((i) => i.json);
const resps = $input.all().map((i) => i.json);
const ctx = reqs[0].ctx;
const window = reqs[0].window;
const incidentAt = new Date(ctx.started_at).getTime();
const suspectMin = envInt(env, 'DEPLOY_SUSPECT_MINUTES', 60, 5, 1440);
let deployRe;
try { deployRe = new RegExp(env.DEPLOY_WORKFLOW_PATTERN || 'deploy|release|\\bcd\\b', 'i'); } catch (e) { deployRe = /deploy|release|\bcd\b/i; }

const changes = [];
const errors = [];
reqs.forEach((req, idx) => {
  const r = resps[idx] || {};
  const c = classifyHttp(r);
  if (c.kind !== 'ok') { errors.push({ request: req.kind, kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.kind === 'auth' ? 'GitHub token rejected or lacks access (needs read-only Contents + Actions).' : c.message }); return; }
  if (req.kind === 'commits' && Array.isArray(r.body)) {
    for (const cm of r.body) {
      const at = cm.commit && cm.commit.committer && cm.commit.committer.date;
      if (!at) continue;
      changes.push({ type: 'commit', ref: String(cm.sha || '').slice(0, 12), at, title: truncate(String((cm.commit.message || '').split('\n')[0]), 150), author: (cm.author && cm.author.login) || (cm.commit.author && cm.commit.author.name) || null, url: cm.html_url || null });
    }
  } else if (req.kind === 'workflow_runs' && r.body && Array.isArray(r.body.workflow_runs)) {
    for (const run of r.body.workflow_runs) {
      const at = run.run_started_at || run.created_at;
      if (!at) continue;
      changes.push({ type: deployRe.test(String(run.name || '') + ' ' + String(run.path || '')) ? 'deployment' : 'workflow_run', ref: String(run.id), at, title: truncate(String(run.name || '') + ' (' + (run.conclusion || run.status || 'unknown') + ') on ' + (run.head_branch || '?'), 150), conclusion: run.conclusion || null, url: run.html_url || null });
    }
  } else {
    errors.push({ request: req.kind, kind: 'invalid_response', message: 'Unexpected GitHub response shape.' });
  }
});

if (errors.length === reqs.length) {
  const auth = errors.some((e) => e.kind === 'auth');
  return [{ json: investigationResult('deployments', ctx, { status: 'unavailable', window, summary: auth ? 'GitHub authentication failed.' : 'GitHub API unavailable.', error: errors[0] }) }];
}

const before = changes
  .filter((ch) => { const t = new Date(ch.at).getTime(); return t <= incidentAt && t >= new Date(window.since).getTime(); })
  .map((ch) => ({ ...ch, minutes_before_incident: Math.round((incidentAt - new Date(ch.at).getTime()) / 60000) }))
  .sort((a, b) => a.minutes_before_incident - b.minutes_before_incident);
const suspects = before.filter((ch) => ch.minutes_before_incident <= suspectMin && (ch.type !== 'workflow_run'));

const findings = [];
const partial = errors.length ? { kind: 'partial', message: errors.map((e) => e.request + ': ' + e.kind).join('; '), details: errors } : null;
if (!before.length) {
  return [{ json: investigationResult('deployments', ctx, { status: 'no_evidence', window, summary: 'No commits or deployments in the ' + window.since + ' – ' + window.until + ' window.', confidence: 0.2, error: partial }) }];
}
findings.push(before.length + ' change(s) in the lookback window; ' + suspects.length + ' within ' + suspectMin + ' minutes before the incident.');
for (const s of suspects.slice(0, 5)) findings.push(s.type + ' ' + s.ref + ' "' + s.title + '" ' + s.minutes_before_incident + ' min before the incident.');

const evidence = before.slice(0, 10).map((ch) => ({ type: ch.type, source: 'github', ref: ch.ref, timestamp: ch.at, value: ch.title, minutes_before_incident: ch.minutes_before_incident, url: ch.url }));
return [{
  json: investigationResult('deployments', ctx, {
    status: suspects.length ? 'evidence_found' : 'no_evidence',
    window,
    summary: suspects.length ? 'Recent change(s) shortly before the incident: possible cause, not confirmed.' : 'Changes found, but none close to the incident time.',
    findings,
    evidence,
    confidence: suspects.length ? (suspects.some((s) => s.type === 'deployment') ? 0.6 : 0.45) : 0.2,
    error: partial,
  }),
}];
