// Workflow 07 – Node: "Return recovery result". 07 always returns its own
// recovery result (contract), with a short summary of the postmortem run.
const recovery = $('Recovery result').first().json;
const pm = $input.first().json || {};
return [{
  json: {
    ...recovery,
    postmortem: { status: pm.status || (pm.error ? 'workflow_failed' : 'unknown'), stored: pm.stored === true, title: pm.postmortem ? pm.postmortem.title : null },
  },
}];
