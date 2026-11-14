// Workflow 07 – Recovery Check (owner: Tharindu)
// Node: "Plan recovery check". Input (from workflow 06):
// { incident_id, playbook_run_id, service_name, action_type, simulated }
//
// Health signals (Prometheus):
//  - up:         min(up{<label>="<service>"}) == 1   (built-in Prometheus metric)
//  - error rate: PROM_QUERY_ERROR_RATE <= PROM_THRESHOLD_ERROR_RATE
// With RECOVERY_REQUIRE_ERROR_RATE=true (default) both are needed to say
// "recovered"; "up" alone is not enough evidence.
//#include lib/common.js

const env = $env;
const j = $input.first().json;
const problems = [];
if (!isUuid(j.incident_id)) problems.push('incident_id must be a UUID');
if (!isUuid(j.playbook_run_id)) problems.push('playbook_run_id must be a UUID');
const base = { incident_id: j.incident_id || null, playbook_run_id: j.playbook_run_id || null, service_name: j.service_name || null, action_type: j.action_type || null, simulated: !!j.simulated };
if (problems.length) return [{ json: { ...base, can_verify: false, verdict: 'unable_to_verify', reason: problems.join('; '), checks: [], attempt: 0 } }];

const promUrl = String(env.PROMETHEUS_URL || '').replace(/\/+$/, '');
let reason = null;
if (!/^https?:\/\//.test(promUrl)) reason = 'PROMETHEUS_URL is not configured.';
else if (!j.service_name || !/^[A-Za-z0-9_.:-]{1,100}$/.test(j.service_name)) reason = 'service_name is unknown (it must be in the playbook run request_payload).';
const label = String(env.PROM_SERVICE_LABEL || 'job');
const requireErrorRate = String(env.RECOVERY_REQUIRE_ERROR_RATE || 'true') !== 'false';
const errTemplate = env.PROM_QUERY_ERROR_RATE;
const errThreshold = env.PROM_THRESHOLD_ERROR_RATE !== undefined && env.PROM_THRESHOLD_ERROR_RATE !== '' ? Number(env.PROM_THRESHOLD_ERROR_RATE) : null;
if (!reason && requireErrorRate && (!errTemplate || errThreshold === null || !Number.isFinite(errThreshold))) {
  reason = 'Error-rate check is required but PROM_QUERY_ERROR_RATE / PROM_THRESHOLD_ERROR_RATE are not configured.';
}
if (reason) return [{ json: { ...base, can_verify: false, verdict: 'unable_to_verify', reason, checks: [], attempt: 0 } }];

const queries = [{ name: 'up', query: 'min(up{' + label + '="' + j.service_name + '"})', healthy_if: 'equals_1' }];
if (errTemplate && errThreshold !== null) {
  queries.push({ name: 'error_rate', query: String(errTemplate).split('{{service}}').join(j.service_name), healthy_if: 'lte', threshold: errThreshold });
}
return [{
  json: {
    ...base,
    can_verify: true,
    prometheus_url: promUrl,
    queries,
    wait_seconds: envInt(env, 'RECOVERY_WAIT_SECONDS', 60, 5, 3600),
    max_checks: envInt(env, 'RECOVERY_MAX_CHECKS', 3, 1, 10),
    timeout_ms: envInt(env, 'PROMETHEUS_TIMEOUT_MS', 10000, 1000, 60000),
    attempt: 0,
    checks: [],
  },
}];
