// Workflow 01 – Node: "Create incident (backend) – BLOCKED".
// One item per new alert.
//
// BLOCKED: the backend has no machine endpoint that creates an incident from an
// alert. The approved contract (database/API_AND_INTEGRATION_CONTRACTS.md, B.3)
// lists only start/complete, investigations/:id/analysis, recovery-checks and
// incident-events, and none of them creates incidents. Until the backend adds
// one, this node does NOT invent a URL: it passes the alert on with
// incident_id = null and records why, so the investigation can still run and
// be tested. When the endpoint exists, replace this node with
// "Sign request" + "HTTP Request" (see workflow 07 for the pattern).

return $input.first().json.alerts.map((a) => ({
  json: {
    incident_id: null,
    investigation_id: null,
    incident_created: false,
    incident_blocker: 'Backend endpoint for creating an incident from an alert does not exist yet (backend dependency BD-1).',
    alert_name: a.alert_name,
    service_name: a.service_name,
    severity: a.severity,
    started_at: a.started_at,
    summary: a.summary,
    dedup_key: a.dedup_key,
  },
}));
