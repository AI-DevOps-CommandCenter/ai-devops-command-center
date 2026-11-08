// Workflow 01 – Node: "Intake result". Summarizes what happened to each alert
// (visible in the n8n execution log).
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
    },
  };
});
