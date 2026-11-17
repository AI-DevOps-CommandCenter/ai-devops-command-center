// Dispatch outbox: approved remediation runs that have not reached n8n yet
// (migration 20261118000200). Runs inside the backend process, next to the
// immediate dispatch after an approval:
//
//   every intervalMs: claim_runs_for_dispatch() (automation identity, atomic,
//   SKIP LOCKED) -> one signed webhook attempt per claimed run.
//
// The database decides what is due (grace after approval, retry interval,
// maximum attempts), so several backend instances never send the same claim.
// A webhook for a run n8n already started is refused there (KI-1 nonce claim,
// start_playbook_run starts a run once).

import type { AutomationClientProvider } from "../config/machine.js";
import {
  isRemediationAction,
  sendRemediationWebhook,
  type RemediationWebhookConfig,
  type WebhookAttemptOutcome
} from "./remediation-webhook.service.js";

export interface DispatchOutboxOptions {
  intervalMs?: number;
  batchSize?: number;
  graceSeconds?: number;
  retrySeconds?: number;
  maxAttempts?: number;
  fetchImpl?: typeof fetch;
  log?: (runId: string, attempt: number, status: string) => void;
}

export interface ClaimedRun {
  run_id: string;
  incident_id: string;
  action_type: string;
  request_payload: Record<string, unknown> | null;
  dispatch_attempts: number;
}

export interface DispatchOutbox {
  // One pass; returns what happened per run (for logs and tests).
  tick(): Promise<{ runId: string; outcome: WebhookAttemptOutcome | "invalid" }[]>;
  start(): void;
  stop(): void;
}

export const OUTBOX_DEFAULTS = {
  intervalMs: 30_000,
  batchSize: 10,
  graceSeconds: 30,
  retrySeconds: 30,
  maxAttempts: 10
};

export function createDispatchOutbox(
  automation: AutomationClientProvider,
  webhook: RemediationWebhookConfig,
  options: DispatchOutboxOptions = {}
): DispatchOutbox {
  const settings = { ...OUTBOX_DEFAULTS, ...options };
  const log = options.log ?? ((runId, attempt, status) =>
    console.info("Remediation outbox attempt", { runId, attempt, status }));
  let timer: ReturnType<typeof setInterval> | null = null;
  let running = false;

  async function claim(): Promise<ClaimedRun[]> {
    const client = await automation.get();
    const { data, error } = await client.rpc("claim_runs_for_dispatch", {
      p_limit: settings.batchSize,
      p_grace_seconds: settings.graceSeconds,
      p_retry_seconds: settings.retrySeconds,
      p_max_attempts: settings.maxAttempts
    });
    if (error) {
      if (String(error.message ?? "").toLowerCase().includes("jwt")) automation.invalidate();
      throw new Error(`claim_runs_for_dispatch failed (${error.code ?? "unknown"}).`);
    }
    return (Array.isArray(data) ? data : []) as ClaimedRun[];
  }

  async function tick() {
    const results: { runId: string; outcome: WebhookAttemptOutcome | "invalid" }[] = [];
    for (const run of await claim()) {
      if (!isRemediationAction(run.action_type) || typeof run.incident_id !== "string") {
        log(run.run_id, run.dispatch_attempts, "invalid_run_data");
        results.push({ runId: run.run_id, outcome: "invalid" });
        continue;
      }
      const { outcome, status } = await sendRemediationWebhook(webhook, {
        playbook_run_id: run.run_id,
        incident_id: run.incident_id,
        action_type: run.action_type,
        request_payload: run.request_payload ?? {}
      }, options.fetchImpl);
      log(run.run_id, run.dispatch_attempts, `outbox_${status}`);
      results.push({ runId: run.run_id, outcome });
    }
    return results;
  }

  return {
    tick,
    start() {
      if (timer) return;
      timer = setInterval(() => {
        if (running) return; // a slow pass is never overlapped
        running = true;
        tick()
          .catch((error: unknown) => console.error("[dispatch-outbox]", error instanceof Error ? error.message : error))
          .finally(() => { running = false; });
      }, settings.intervalMs);
      timer.unref?.();
    },
    stop() {
      if (timer) clearInterval(timer);
      timer = null;
    }
  };
}

// Interval from REMEDIATION_OUTBOX_INTERVAL_MS (default 30 s, 0 = disabled).
export function outboxIntervalFromEnv(env: NodeJS.ProcessEnv = process.env): number {
  const raw = env.REMEDIATION_OUTBOX_INTERVAL_MS?.trim();
  if (!raw) return OUTBOX_DEFAULTS.intervalMs;
  const value = Number(raw);
  if (!Number.isInteger(value) || (value !== 0 && (value < 5_000 || value > 600_000))) {
    throw new Error("REMEDIATION_OUTBOX_INTERVAL_MS must be 0 (off) or an integer from 5000 to 600000.");
  }
  return value;
}
