// Workflow 01 – Node: "Intake result". Summarizes what happened to each alert
// (visible in the n8n execution log). soft_failure (N-2) is the one returned by
// workflow 05 (AI unavailable, analysis not stored); "Soft failure?" sends it to 09.
const alerts = $('Create incident (backend) – BLOCKED').all().map((i) => i.json);
return $input.all().map((item, idx) => {
  const rca = item.json || {};
  const a = alerts[idx] || {};
  return {
    json: {
      alert_name: a.alert_name,
      service_name: a.service_name,
      incident_id: a.incident_id,
      incident_created: a.incident_created,
      rca_status: rca.status || (rca.error ? 'workflow_error' : 'unknown'),
      rca_stored: rca.stored === true,
      error: rca.error || null,
      soft_failure: rca.soft_failure && typeof rca.soft_failure === 'object' ? rca.soft_failure : null,
    },
  };
});
