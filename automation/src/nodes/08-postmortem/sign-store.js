// Workflow 08 – Node: "Sign store postmortem request".
//   POST /api/machine/incidents/:id/postmortem   body = the validated postmortem
// (BD-4 -> save_postmortem; one automation postmortem per incident, a re-run
// updates it). 201 { data: { postmortem_id } }. Skipped when the draft is not
// valid or there is no incident id.
//#include lib/hmac.js
//#include lib/common.js

const d = $input.first().json;
if (!d.valid || !d.postmortem || !isUuid(d.incident_id)) {
  return [{ json: { ...d, request: null, skip_store: true } }];
}
try {
  const request = signedBackendRequest($env, 'POST', '/api/machine/incidents/' + d.incident_id + '/postmortem', d.postmortem);
  return [{ json: { ...d, request, skip_store: false } }];
} catch (e) {
  return [{ json: { ...d, request: null, skip_store: true, store_error: { kind: 'not_configured', message: String(e.message || e) } } }];
}
