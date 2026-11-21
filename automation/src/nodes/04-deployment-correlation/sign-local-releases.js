// Workflow 04 – Node: "Sign local releases request". Runs after the GitHub
// calls (or straight after "Build GitHub requests" when GitHub is not
// configured). Keeps the GitHub responses and builds the signed
// GET /api/machine/deployments for the releases release.sh recorded in the
// lookback window. Without signing config the local check is skipped.
//#include lib/hmac.js
//#include lib/common.js

const reqs = $('Build GitHub requests').all().map((i) => i.json);
const first = reqs[0];
const githubConfigured = first.kind !== 'none';
const githubResponses = githubConfigured ? $input.all().map((i) => i.json) : [];

let request = null;
let signError = null;
try {
  // service_name is validated ([A-Za-z0-9_.:-]) and ISO timestamps only use
  // [0-9TZ:.-], so the query needs no encoding: the signed path is exactly
  // the path the backend sees (req.originalUrl).
  const path = '/api/machine/deployments?service_name=' + first.ctx.service_name +
    '&since=' + first.window.since + '&until=' + first.window.until;
  request = signedBackendRequest($env, 'GET', path);
} catch (e) {
  signError = String(e.message || e);
}

return [{
  json: {
    ctx: first.ctx,
    window: first.window,
    github_configured: githubConfigured,
    github_reason: first.github_reason || null,
    github_responses: githubResponses,
    request,
    skip_local: !request,
    sign_error: signError,
  },
}];
