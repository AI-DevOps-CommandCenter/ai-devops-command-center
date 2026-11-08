// Workflow 06 – Node: "Unsupported or rejected action". Reached when the
// approved playbook's action is not one of the four supported branches, or when
// the start result did not match the request. Nothing is executed.
const d = $input.first().json;
return [{ json: { ...d, outcome: 'failed', result: { action: d.action_type || null, executed: false, reason: d.rejection || 'Unsupported action type.' } } }];
