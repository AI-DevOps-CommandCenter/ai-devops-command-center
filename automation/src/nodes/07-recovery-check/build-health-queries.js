// Workflow 07 – Node: "Build health queries". Runs after every Wait, in a
// loop. Input is the plan (first time) or the previous evaluation (later).
//#include lib/common.js

const s = $input.first().json;
const attempt = (s.attempt || 0) + 1;
const at = new Date().toISOString();
return s.queries.map((q) => ({
  json: {
    state: { ...s, attempt },
    check: q,
    url: s.prometheus_url + '/api/v1/query?' + toQuery({ query: q.query, time: at }),
    timeout_ms: s.timeout_ms,
  },
}));
