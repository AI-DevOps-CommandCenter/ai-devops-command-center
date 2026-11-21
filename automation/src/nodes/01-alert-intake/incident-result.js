// Workflow 01 – Node: "Incident result". Pairs each HTTP answer with its alert
// (same order as "Sign create incident request") and sets:
//   incident_status "created" -> incident (new or existing) is known; 05 stores its analysis
//   incident_status "failed"  -> no incident; "Confirm alert processing" releases the
//                                alert so the next Alertmanager delivery retries (N-3)
//#include lib/common.js

const signed = $('Sign create incident request').all().map((i) => i.json);
return $input.all().map((item, idx) => {
  const s = signed[idx] || {};
  const { request, sign_error, ...alert } = s;
  const response = item.json || {};
  if (sign_error) {
    return { json: { ...alert, incident_id: null, investigation_id: null, incident_created: false, incident_status: 'failed', incident_error: { kind: 'not_configured', message: sign_error } } };
  }
  const c = classifyHttp(response);
  const data = c.kind === 'ok' && response.body && response.body.data ? response.body.data : null;
  if (!data || !data.incident_id) {
    return { json: { ...alert, incident_id: null, investigation_id: null, incident_created: false, incident_status: 'failed', incident_error: { kind: c.kind, http_status: c.status, message: c.message } } };
  }
  return {
    json: {
      ...alert,
      incident_id: data.incident_id,
      investigation_id: data.investigation_id || null,
      incident_created: data.created === true,
      incident_status: 'created',
      incident_error: null,
    },
  };
});
