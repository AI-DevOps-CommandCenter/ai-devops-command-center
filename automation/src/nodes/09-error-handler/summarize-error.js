// Workflow 09 – Error Handler (shared)
// Node: "Summarize error". Input from the Error Trigger:
// { execution: { id, url, error: { message, stack, node? }, lastNodeExecuted, mode }, workflow: { id, name } }
// Only a short, redacted summary leaves n8n: no stack traces, no input data.
//
// ERROR_NOTIFY_WEBHOOK_URL is a secret (the token is part of the URL). It is
// read here only to decide whether a notification is configured, and it is
// never written to the output: n8n stores node output in the execution
// history. The "Send notification" HTTP node reads the URL from $env itself.
//#include lib/common.js

const env = $env;
const j = $input.first().json;
const ex = j.execution || {};
const err = ex.error || {};
const notifyUrl = String(env.ERROR_NOTIFY_WEBHOOK_URL || '');
// Removes the configured webhook URL from a text, even when it is not a
// Slack/Discord URL that redact() recognizes.
const stripNotifyUrl = (text) => (notifyUrl ? String(text).split(notifyUrl).join('[REDACTED]') : String(text));
const message = redact(truncate(stripNotifyUrl(err.message || 'Unknown error'), 300));
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
return [{
  json: {
    ...summary,
    notify: /^https:\/\//.test(notifyUrl),
    // Slack incoming webhooks read "text", Discord webhooks read "content".
    body: JSON.stringify({ text, content: text }),
    timeout_ms: 10000,
  },
}];
