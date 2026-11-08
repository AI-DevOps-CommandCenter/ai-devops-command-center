// Workflow 01 – Node: "Detect duplicate alerts".
// Alertmanager re-sends the same firing alert every repeat_interval. An alert
// occurrence is identified by fingerprint + startsAt; it is processed once per
// DEDUP_WINDOW_MINUTES (default 360). The store is the workflow's static data,
// which n8n saves only for production (active) executions, not manual tests.
//#include lib/common.js

const env = $env;
const data = $input.first().json;
const store = $getWorkflowStaticData('global');
store.seenAlerts = store.seenAlerts || {};
const seen = store.seenAlerts;
const now = Date.now();
const windowMs = envInt(env, 'DEDUP_WINDOW_MINUTES', 360, 1, 10080) * 60000;

for (const [k, at] of Object.entries(seen)) if (now - at > windowMs) delete seen[k];

const fresh = [];
const duplicates = [];
for (const a of data.alerts) {
  const key = (a.fingerprint || (a.alert_name + '|' + a.service_name)) + '|' + a.started_at;
  if (seen[key]) { duplicates.push({ alert_name: a.alert_name, service_name: a.service_name, key }); continue; }
  seen[key] = now;
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
