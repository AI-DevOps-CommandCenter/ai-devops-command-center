// Workflow 09 – Error Handler (shared)
// Node: "Summarize error". Input from the Error Trigger:
// { execution: { id, url, error: { message, stack, node? }, lastNodeExecuted, mode }, workflow: { id, name } }
// Only a short, redacted summary leaves n8n: no stack traces, no input data.
//#include lib/common.js

const env = $env;
const j = $input.first().json;
const ex = j.execution || {};
const err = ex.error || {};
const message = redact(truncate(err.message || 'Unknown error', 300));
const node = (err.node && err.node.name) || ex.lastNodeExecuted || null;

// Transient problems are worth retrying; configuration and validation errors are not.
const retryable = /timeout|timed out|ETIMEDOUT|ESOCKETTIMEDOUT|ECONNRESET|ECONNREFUSED|ENOTFOUND|EAI_AGAIN|socket hang up|429|rate limit|502|503|504/i.test(err.message || '');
const permanent = /401|403|unauthori[sz]ed|forbidden|not configured|invalid|must be|required/i.test(err.message || '');

const summary = {
  workflow: (j.workflow && j.workflow.name) || 'unknown',
  workflow_id: (j.workflow && j.workflow.id) || null,
  execution_id: ex.id || null,
  execution_url: ex.url || null,
  mode: ex.mode || null,
  failed_node: node,
  message,
  retryable: retryable && !permanent,
  at: new Date().toISOString(),
};
const text = '[n8n] ' + summary.workflow + ' failed at "' + (node || '?') + '": ' + message + (summary.retryable ? ' (retryable)' : '') + (summary.execution_url ? '\n' + summary.execution_url : '');
const url = env.ERROR_NOTIFY_WEBHOOK_URL || '';
return [{
  json: {
    ...summary,
    notify: /^https:\/\//.test(url),
    url,
    // Slack incoming webhooks read "text", Discord webhooks read "content".
    body: JSON.stringify({ text, content: text }),
    timeout_ms: 10000,
  },
}];
