// Workflow 01 – Node: "Sign create incident request". One item per new alert.
// Builds the signed request for POST /api/machine/incidents (BD-1, backend
// machine.routes.ts -> create_incident_from_alert). The backend returns 201
// (created) or 200 (an active incident for this alert already exists); both
// give { incident_id, investigation_id, created }.
// fingerprint: Alertmanager's alert fingerprint (stable per alert labels), or
// alertname + service when Alertmanager sent none.
//#include lib/hmac.js
//#include lib/common.js

return $input.first().json.alerts.map((a) => {
  const base = {
    alert_name: a.alert_name,
    service_name: a.service_name,
    severity: a.severity,
    started_at: a.started_at,
    summary: a.summary,
    dedup_key: a.dedup_key,
  };
  const fingerprint = a.fingerprint || truncate((a.alert_name || 'alert') + ':' + a.service_name, 200);
  try {
    const request = signedBackendRequest($env, 'POST', '/api/machine/incidents', {
      fingerprint,
      title: truncate((a.alert_name || 'Alert') + ' on ' + a.service_name, 300),
      description: a.description || a.summary || null,
      severity: a.severity,
      service_name: a.service_name,
      environment: (a.labels && (a.labels.environment || a.labels.env)) || null,
      detected_at: a.started_at,
    });
    return { json: { ...base, request, sign_error: null } };
  } catch (e) {
    return { json: { ...base, request: null, sign_error: String(e.message || e) } };
  }
});
