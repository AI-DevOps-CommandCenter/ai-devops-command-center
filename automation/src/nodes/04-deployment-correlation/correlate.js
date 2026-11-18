// Workflow 04 – Node: "Correlate changes". A change is "suspect" when it
// happened within DEPLOY_SUSPECT_MINUTES (default 60) before the incident.
// Sources: GitHub commits and workflow runs (runs whose name matches
// DEPLOY_WORKFLOW_PATTERN, default deploy|release|cd, are deployments) and
// local releases recorded by release.sh (always deployments). A recent local
// release is the strongest signal: a new version went out just before the
// errors, which a rollback fixes and a restart does not.
// Input: the backend response for local releases, or the "Sign local
// releases request" item itself when that request was skipped.
//#include lib/common.js

const env = $env;
const signed = $('Sign local releases request').first().json;
const ctx = signed.ctx;
const window = signed.window;
const incidentAt = new Date(ctx.started_at).getTime();
const sinceAt = new Date(window.since).getTime();
const suspectMin = envInt(env, 'DEPLOY_SUSPECT_MINUTES', 60, 5, 1440);
let deployRe;
try { deployRe = new RegExp(env.DEPLOY_WORKFLOW_PATTERN || 'deploy|release|\\bcd\\b', 'i'); } catch (e) { deployRe = /deploy|release|\bcd\b/i; }

const changes = [];
const errors = [];
let sourcesTried = 0;

// ---- GitHub ----
if (signed.github_configured) {
  const reqs = $('Build GitHub requests').all().map((i) => i.json);
  const resps = signed.github_responses || [];
  reqs.forEach((req, idx) => {
    sourcesTried += 1;
    const r = resps[idx] || {};
    const c = classifyHttp(r);
    if (c.kind !== 'ok') { errors.push({ request: req.kind, kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.kind === 'auth' ? 'GitHub token rejected or lacks access (needs read-only Contents + Actions).' : c.message }); return; }
    if (req.kind === 'commits' && Array.isArray(r.body)) {
      for (const cm of r.body) {
        const at = cm.commit && cm.commit.committer && cm.commit.committer.date;
        if (!at) continue;
        changes.push({ type: 'commit', source: 'github', ref: String(cm.sha || '').slice(0, 12), at, title: truncate(String((cm.commit.message || '').split('\n')[0]), 150), url: cm.html_url || null });
      }
    } else if (req.kind === 'workflow_runs' && r.body && Array.isArray(r.body.workflow_runs)) {
      for (const run of r.body.workflow_runs) {
        const at = run.run_started_at || run.created_at;
        if (!at) continue;
        changes.push({ type: deployRe.test(String(run.name || '') + ' ' + String(run.path || '')) ? 'deployment' : 'workflow_run', source: 'github', ref: String(run.id), at, title: truncate(String(run.name || '') + ' (' + (run.conclusion || run.status || 'unknown') + ') on ' + (run.head_branch || '?'), 150), url: run.html_url || null });
      }
    } else {
      errors.push({ request: req.kind, kind: 'invalid_response', message: 'Unexpected GitHub response shape.' });
    }
  });
}

// ---- local releases (release.sh) ----
let localChecked = false;
if (!signed.skip_local) {
  sourcesTried += 1;
  const r = $input.first().json || {};
  const c = classifyHttp(r, { notFoundMeansNotImplemented: true, serviceUnavailableMeansNotConfigured: true });
  const list = r.body && r.body.data && r.body.data.deployments;
  if (c.kind !== 'ok') {
    errors.push({ request: 'local_releases', kind: c.kind, http_status: c.status, retryable: c.retryable, message: c.message });
  } else if (!Array.isArray(list)) {
    errors.push({ request: 'local_releases', kind: 'invalid_response', message: 'Unexpected backend response shape.' });
  } else {
    localChecked = true;
    for (const d of list.slice(0, 20)) {
      if (!d || !d.completed_at || !d.version) continue;
      changes.push({ type: 'deployment', source: 'local', ref: truncate(String(d.version), 64), at: d.completed_at, title: truncate('local release ' + String(d.service_name || ctx.service_name) + ' ' + String(d.version) + ' (' + String(d.status || 'success') + ')', 150), version: String(d.version), url: null });
    }
  }
}

const notes = [];
if (!signed.github_configured) notes.push(signed.github_reason || 'GitHub is not configured.');
if (signed.skip_local) notes.push('Local releases not checked: ' + (signed.sign_error || 'backend signing is not configured.'));

if (sourcesTried === 0) {
  return [{ json: investigationResult('deployments', ctx, { status: 'not_configured', window, summary: 'No change source is configured (GitHub or local releases).', error: { kind: 'not_configured', message: notes.join(' ') } }) }];
}
if (errors.length === sourcesTried) {
  const auth = errors.some((e) => e.kind === 'auth');
  return [{ json: investigationResult('deployments', ctx, { status: 'unavailable', window, summary: auth ? 'Change sources rejected the credentials.' : 'Change sources unavailable.', error: errors[0] }) }];
}

const before = changes
  .filter((ch) => { const t = new Date(ch.at).getTime(); return t <= incidentAt && t >= sinceAt; })
  .map((ch) => ({ ...ch, minutes_before_incident: Math.round((incidentAt - new Date(ch.at).getTime()) / 60000) }))
  // Local releases first at equal distance; then the closest change first.
  .sort((a, b) => a.minutes_before_incident - b.minutes_before_incident || (a.source === 'local' ? -1 : 0) - (b.source === 'local' ? -1 : 0));
const suspects = before.filter((ch) => ch.minutes_before_incident <= suspectMin && ch.type !== 'workflow_run');
const localSuspect = suspects.find((s) => s.source === 'local');

const partial = errors.length || notes.length
  ? { kind: 'partial', message: [...errors.map((e) => e.request + ': ' + e.kind), ...notes].join('; '), details: errors }
  : null;
if (!before.length) {
  return [{ json: investigationResult('deployments', ctx, { status: 'no_evidence', window, summary: 'No commits, deployments or local releases in the ' + window.since + ' – ' + window.until + ' window.', confidence: 0.2, error: partial }) }];
}

const findings = [];
if (localSuspect) {
  findings.push('Release ' + ctx.service_name + ' ' + localSuspect.version + ' went out ' + localSuspect.minutes_before_incident + ' min before the incident. A bad release is fixed by a rollback, not by a restart.');
}
findings.push(before.length + ' change(s) in the lookback window; ' + suspects.length + ' within ' + suspectMin + ' minutes before the incident.');
for (const s of suspects.slice(0, 5)) findings.push(s.type + (s.source === 'local' ? ' (local)' : '') + ' ' + s.ref + ' "' + s.title + '" ' + s.minutes_before_incident + ' min before the incident.');
if (!localChecked && !signed.skip_local) findings.push('Local releases could not be read; only GitHub was checked.');

const evidence = before.slice(0, 10).map((ch) => ({ type: ch.type, source: ch.source, ref: ch.ref, timestamp: ch.at, value: ch.title, minutes_before_incident: ch.minutes_before_incident, url: ch.url }));
let confidence = 0.2;
if (suspects.length) confidence = localSuspect ? 0.7 : (suspects.some((s) => s.type === 'deployment') ? 0.6 : 0.45);
return [{
  json: investigationResult('deployments', ctx, {
    status: suspects.length ? 'evidence_found' : 'no_evidence',
    window,
    summary: localSuspect
      ? 'A new release (' + localSuspect.version + ') went out ' + localSuspect.minutes_before_incident + ' min before the incident: likely cause, not confirmed.'
      : (suspects.length ? 'Recent change(s) shortly before the incident: possible cause, not confirmed.' : 'Changes found, but none close to the incident time.'),
    findings,
    evidence,
    confidence,
    error: partial,
  }),
}];
