import "../config/load-env.js";

import { startNotificationWorker } from "./notification-dispatcher.js";

// Standalone notification worker (npm run worker:notifications). The API
// server runs the same loop in-process (server.ts); run this instead only when
// the API is started with NOTIFICATION_WORKER_POLL_INTERVAL_MS=0.

startNotificationWorker(process.env, { keepAlive: true })
  .then((result) => {
    if (result.started) {
      console.log(`[notification-worker] running for: ${result.channels.join(", ")}`);
    } else {
      console.error(`[notification-worker] not started: ${result.reason}`);
      process.exitCode = 1;
    }
  })
  .catch((error: unknown) => {
    console.error(`[notification-worker] ${error instanceof Error ? error.message : "Unknown worker startup error."}`);
    process.exitCode = 1;
  });
