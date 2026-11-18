import { loadSupabaseEnv } from "../config/env.js";
import { createAutomationClientProvider, loadAutomationEnv, type AutomationClientProvider } from "../config/machine.js";
import { createAllNotificationSenders } from "../integrations/notifications/index.js";
import type { DeliveryResult, NotificationSender } from "../integrations/notifications/types.js";
import {
  claimNotificationDeliveries,
  recordNotificationDelivery,
  type NotificationDelivery
} from "../services/notification-delivery.service.js";
import { processNotificationDeliveryBatch, type NotificationBatchResult } from "./notification-delivery-processor.js";

// Notification worker loop (decision A6): claims pending deliveries with the
// automation identity, sends each one with the sender for its channel and
// records the result.
//
// Retry policy (no migration needed): a retryable failure is NOT recorded, so
// the delivery stays pending and claim_notification_deliveries() hands it out
// again after its 2 minute back-off. After maxAttempts claims it is recorded
// as failed. A channel without a sender on this backend (not configured) is
// treated like a retryable failure, so configuring it later still delivers.
//
// Runs inside the API process (started from server.ts) or on its own
// (npm run worker:notifications). One batch at a time: a slow tick is never
// overlapped by the next one.

export interface NotificationDispatcherOptions {
  intervalMs: number;
  batchSize: number;
  maxAttempts: number;
  log?: (line: string) => void;
  // false (default): the timer does not keep the process alive (API server).
  keepAlive?: boolean;
}

export function notificationWorkerOptionsFromEnv(env: NodeJS.ProcessEnv = process.env) {
  const int = (name: string, fallback: number, min: number, max: number, allowZero = false) => {
    const raw = env[name]?.trim() ?? "";
    const value = raw === "" ? fallback : Number(raw);
    if (!Number.isInteger(value) || ((value < min || value > max) && !(allowZero && value === 0))) {
      throw new Error(`${name} must be an integer between ${min} and ${max}${allowZero ? " (or 0 = off)" : ""}.`);
    }
    return value;
  };
  return {
    intervalMs: int("NOTIFICATION_WORKER_POLL_INTERVAL_MS", 10_000, 1_000, 3_600_000, true),
    batchSize: int("NOTIFICATION_WORKER_BATCH_SIZE", 50, 1, 500),
    maxAttempts: int("NOTIFICATION_MAX_ATTEMPTS", 5, 1, 20)
  };
}

export function sendWithSenders(senders: Map<string, NotificationSender>) {
  return async (delivery: NotificationDelivery): Promise<DeliveryResult> => {
    const sender = senders.get(delivery.channel);
    if (!sender) {
      return { status: "failed", errorMessage: `No ${delivery.channel} sender is configured on the backend.`, retryable: true };
    }
    return sender.send(delivery);
  };
}

export function createNotificationDispatcher(
  automation: AutomationClientProvider,
  senders: Map<string, NotificationSender>,
  options: NotificationDispatcherOptions
) {
  const log = options.log ?? ((line: string) => console.log(line));
  let timer: NodeJS.Timeout | null = null;
  let running = false;

  async function tick(): Promise<NotificationBatchResult | null> {
    if (running) return null;
    running = true;
    try {
      const client = await automation.get();
      const result = await processNotificationDeliveryBatch(
        {
          claim: (limit) => claimNotificationDeliveries(client, limit),
          send: sendWithSenders(senders),
          record: (id, status, providerMessageId, errorMessage) =>
            recordNotificationDelivery(client, id, status, providerMessageId, errorMessage)
        },
        options.batchSize,
        options.maxAttempts
      );
      if (result.claimed > 0) {
        log(`[notification-worker] claimed ${result.claimed}: ${result.succeeded} sent, ${result.failed} failed, ${result.retrying} retry later`);
      }
      return result;
    } catch (error) {
      // Claim or record failed (database unreachable...). The next tick tries
      // again; claimed rows come back after the 2 minute back-off.
      // Supabase returns plain error objects (not always Error instances).
      const message = typeof error === "object" && error !== null && "message" in error ? String((error as { message: unknown }).message) : "unknown error";
      if (message.toLowerCase().includes("jwt")) automation.invalidate();
      log(`[notification-worker] batch failed: ${message.slice(0, 200)}`);
      return null;
    } finally {
      running = false;
    }
  }

  return {
    tick,
    start() {
      if (timer) return;
      timer = setInterval(() => { void tick(); }, options.intervalMs);
      if (!options.keepAlive) timer.unref();
      void tick();
    },
    stop() {
      if (timer) clearInterval(timer);
      timer = null;
    }
  };
}

// Builds the senders and the automation client from the environment and
// starts the loop. Returns why it did not start instead of throwing, so the
// API keeps running without notifications. keepAlive: the standalone worker
// keeps the process running on the timer.
export async function startNotificationWorker(
  env: NodeJS.ProcessEnv = process.env,
  { keepAlive = false, log = (line: string) => console.log(line) } = {}
): Promise<{ started: true; channels: string[] } | { started: false; reason: string }> {
  let options;
  try {
    options = notificationWorkerOptionsFromEnv(env);
  } catch (error) {
    return { started: false, reason: (error as Error).message };
  }
  if (options.intervalMs === 0) return { started: false, reason: "NOTIFICATION_WORKER_POLL_INTERVAL_MS=0" };

  const automationEnv = loadAutomationEnv(env);
  if (!automationEnv) return { started: false, reason: "needs AUTOMATION_EMAIL and AUTOMATION_PASSWORD" };

  let senders: Map<string, NotificationSender>;
  try {
    senders = await createAllNotificationSenders(env);
  } catch (error) {
    return { started: false, reason: (error as Error).message.slice(0, 300) };
  }
  if (senders.size === 0) return { started: false, reason: "no channel configured (SMTP_*, SLACK_WEBHOOK_URL, DISCORD_WEBHOOK_URL, FIREBASE_SERVICE_ACCOUNT_FILE)" };

  const supabaseEnv = loadSupabaseEnv(env);
  const automation = createAutomationClientProvider({
    supabaseUrl: supabaseEnv.SUPABASE_URL,
    publishableKey: supabaseEnv.SUPABASE_PUBLISHABLE_KEY,
    email: automationEnv.automationEmail,
    password: automationEnv.automationPassword
  });
  createNotificationDispatcher(automation, senders, { ...options, log, keepAlive }).start();
  return { started: true, channels: [...senders.keys()] };
}
