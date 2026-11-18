// Must stay the first import: loads .env before any config is read.
import "./config/load-env.js";

import { createApp } from "./app.js";
import { loadServerConfig, loadSupabaseEnv } from "./config/env.js";
import {
  createAutomationClientProvider,
  loadAutomationEnv,
  loadRemediationWebhookEnv
} from "./config/machine.js";
import { createDispatchOutbox, outboxIntervalFromEnv } from "./services/dispatch-outbox.service.js";
import { startNotificationWorker } from "./workers/notification-dispatcher.js";

const config = loadServerConfig();
const app = createApp(config);

app.listen(config.port, () => {
  console.log(`Server running at http://localhost:${config.port}`);
});

// Notification worker (decision A6): delivers email, Slack, Discord and push
// notifications. Needs the automation identity and at least one configured
// channel; NOTIFICATION_WORKER_POLL_INTERVAL_MS=0 turns it off.
void startNotificationWorker().then((result) => {
  console.log(result.started
    ? `Notification worker: on (${result.channels.join(", ")})`
    : `Notification worker: off (${result.reason})`);
});

// Dispatch outbox (migration 20261118000200): sends approved remediation runs
// to n8n again until they start. Needs the webhook settings and the automation
// identity; REMEDIATION_OUTBOX_INTERVAL_MS=0 turns it off.
const webhook = loadRemediationWebhookEnv();
const automationEnv = loadAutomationEnv();
const outboxIntervalMs = outboxIntervalFromEnv();
if (webhook && automationEnv && outboxIntervalMs > 0) {
  const supabaseEnv = loadSupabaseEnv();
  const automation = createAutomationClientProvider({
    supabaseUrl: supabaseEnv.SUPABASE_URL,
    publishableKey: supabaseEnv.SUPABASE_PUBLISHABLE_KEY,
    email: automationEnv.automationEmail,
    password: automationEnv.automationPassword
  });
  createDispatchOutbox(automation, { url: webhook.url, signingSecret: webhook.signingSecret }, { intervalMs: outboxIntervalMs }).start();
  console.log(`Remediation dispatch outbox: every ${outboxIntervalMs / 1000} s`);
} else {
  console.log("Remediation dispatch outbox: off (needs N8N_REMEDIATION_WEBHOOK_URL, MACHINE_SIGNING_SECRET and the automation identity)");
}
