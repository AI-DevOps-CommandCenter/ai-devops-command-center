import "../config/load-env.js";

import {
  loadAutomationEnv
} from "../config/machine.js";

import {
  claimNotificationDeliveries,
  recordNotificationDelivery
} from "../services/notification-delivery.service.js";

import {
  processNotificationDeliveryBatch
} from "./notification-delivery-processor.js";

const POLL_INTERVAL_MS = Number(
  process.env.NOTIFICATION_WORKER_POLL_INTERVAL_MS ?? 10_000
);

const BATCH_SIZE = Number(
  process.env.NOTIFICATION_WORKER_BATCH_SIZE ?? 50
);

function validateWorkerConfig(): void {
  if (
    !Number.isInteger(POLL_INTERVAL_MS) ||
    POLL_INTERVAL_MS < 1_000
  ) {
    throw new Error(
      "NOTIFICATION_WORKER_POLL_INTERVAL_MS must be an integer of at least 1000."
    );
  }

  if (
    !Number.isInteger(BATCH_SIZE) ||
    BATCH_SIZE < 1 ||
    BATCH_SIZE > 500
  ) {
    throw new Error(
      "NOTIFICATION_WORKER_BATCH_SIZE must be an integer between 1 and 500."
    );
  }
}

async function main(): Promise<void> {
  validateWorkerConfig();

  const automationEnv = loadAutomationEnv();

  if (!automationEnv) {
    throw new Error(
      "Notification worker is disabled: configure AUTOMATION_EMAIL and AUTOMATION_PASSWORD."
    );
  }

  // No real provider adapters have been configured yet.
  // Do not claim database deliveries until at least one is available.
  throw new Error(
    "Notification worker is not started: no notification provider adapters are configured."
  );

  // The automation client and processing loop will be connected
  // after provider configuration is implemented.
}

main().catch((error: unknown) => {
  const message =
    error instanceof Error ? error.message : "Unknown worker startup error.";

  console.error(`[notification-worker] ${message}`);
  process.exitCode = 1;
});