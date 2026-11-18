// Must stay the first import: loads .env before any config is read.
import "./config/load-env.js";

import { createApp } from "./app.js";
import { loadServerConfig } from "./config/env.js";
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
