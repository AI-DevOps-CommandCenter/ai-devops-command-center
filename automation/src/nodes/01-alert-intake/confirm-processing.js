// Workflow 01 – Node: "Confirm alert processing" (N-3). Runs after the incident
// step, once per new alert (one item per alert, dedup_key set by "Detect
// duplicate alerts"):
//   incident_status "created" -> confirmed (duplicates are skipped for DEDUP_WINDOW_MINUTES)
//   incident_status "blocked" -> confirmed: BD-1 does not exist, nothing was
//                                attempted and the investigation still runs, so
//                                the occurrence is processed once (behaviour
//                                before N-3, unchanged)
//   anything else ("failed", missing) -> released: the key is removed, so the
//                                next delivery of this alert (Alertmanager repeat)
//                                is processed again.
// Items are passed on unchanged (plus dedup_state).

const store = $getWorkflowStaticData('global');
store.seenAlerts = store.seenAlerts || {};
const seen = store.seenAlerts;
const now = Date.now();
return $input.all().map((item) => {
  const j = item.json || {};
  let dedupState = 'none';
  if (typeof j.dedup_key === 'string' && j.dedup_key) {
    if (j.incident_status === 'created' || j.incident_status === 'blocked') {
      seen[j.dedup_key] = { state: 'confirmed', at: now };
      dedupState = 'confirmed';
    } else {
      delete seen[j.dedup_key];
      dedupState = 'released';
    }
  }
  return { json: { ...j, dedup_state: dedupState } };
});
