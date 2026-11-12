// Workflow 01 – Node: "Detect duplicate alerts".
// Alertmanager re-sends the same firing alert every repeat_interval. An alert
// occurrence is identified by fingerprint + startsAt; it is processed once per
// DEDUP_WINDOW_MINUTES (default 360). The store is the workflow's static data,
// which n8n saves only for production (active) executions, not manual tests.
//
// N-3 (pending/confirmed): a new occurrence is first marked "pending". Only
// "Confirm alert processing" (after the incident step) marks it "confirmed"
// (incident created, or creation not available yet: BD-1) or RELEASES it
// (creation failed), so the next delivery is processed again instead of being
// dropped for 6 hours. A "pending" entry left by an execution that never
// finished (crash) expires after DEDUP_PENDING_MINUTES (default 15).
//
// LIMITATION (documented, not solved here): n8n loads static data when an
// execution starts and saves it when the execution ends. Two deliveries of the
// same alert that are processed AT THE SAME TIME do not see each other, so both
// are processed. Real protection needs BD-1 to be idempotent on the alert
// fingerprint in the database (needs a schema change: incidents has no
// fingerprint column today).
//
// Entries: { state: 'pending' | 'confirmed', at: <ms> }. A plain number (written
// by the previous version of this node) is read as "confirmed at <ms>".
//#include lib/common.js

const env = $env;
const data = $input.first().json;
const store = $getWorkflowStaticData('global');
store.seenAlerts = store.seenAlerts || {};
const seen = store.seenAlerts;
const now = Date.now();
const windowMs = envInt(env, 'DEDUP_WINDOW_MINUTES', 360, 1, 10080) * 60000;
const pendingMs = Math.min(windowMs, envInt(env, 'DEDUP_PENDING_MINUTES', 15, 1, 1440) * 60000);

const entryOf = (v) => {
  if (typeof v === 'number' && Number.isFinite(v)) return { state: 'confirmed', at: v };
  if (v && typeof v === 'object' && (v.state === 'pending' || v.state === 'confirmed') && Number.isFinite(v.at)) return v;
  return null;
};

for (const [k, v] of Object.entries(seen)) {
  const e = entryOf(v);
  if (!e || now - e.at > (e.state === 'pending' ? pendingMs : windowMs)) delete seen[k];
}

const fresh = [];
const duplicates = [];
for (const a of data.alerts) {
  const key = (a.fingerprint || (a.alert_name + '|' + a.service_name)) + '|' + a.started_at;
  const e = entryOf(seen[key]);
  if (e) {
    duplicates.push({ alert_name: a.alert_name, service_name: a.service_name, key, state: e.state === 'pending' ? 'in_progress' : 'processed' });
    continue;
  }
  seen[key] = { state: 'pending', at: now };
  fresh.push({ ...a, dedup_key: key });
}

return [{
  json: {
    ...data,
    alerts: fresh,
    duplicates,
    response: {
      accepted: true,
      new_alerts: fresh.length,
      duplicate_alerts: duplicates.length,
      resolved_alerts: data.resolved,
      rejected_alerts: data.rejected.length,
      rejected: data.rejected,
    },
  },
}];
