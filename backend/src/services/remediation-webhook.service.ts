import { randomBytes } from "node:crypto";
import type { UserSupabaseClient } from "../config/supabase.js";
import { getPlaybookRunById } from "./playbook-run.service.js";
import { buildSignedHeaders } from "../middleware/machine-auth.js";

const WEBHOOK_PATH = "/webhook/remediation";
const RETRY_DELAYS_MS = [2000, 5000, 10000];
const REQUEST_TIMEOUT_MS = 10000;

const ALLOWED_ACTIONS = [
  "restart",
  "rollback",
  "scale",
  "circuit_breaker"
] as const;

export interface RemediationWebhookConfig {
  url: string;
  signingSecret: string;
}

export interface RemediationWebhookDispatcher {
  dispatch(client: UserSupabaseClient, runId: string): Promise<void>;
}

type FetchFunction = typeof fetch;

interface DispatcherOptions {
  fetchImpl?: FetchFunction;
  sleep?: (milliseconds: number) => Promise<void>;
  log?: (runId: string, attempt: number, status: string) => void;
}

function defaultSleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function isAllowedAction(
  action: string
): action is (typeof ALLOWED_ACTIONS)[number] {
  return ALLOWED_ACTIONS.includes(
    action as (typeof ALLOWED_ACTIONS)[number]
  );
}

async function getPlaybookActionType(
  client: UserSupabaseClient,
  playbookId: unknown
): Promise<string | null> {
  if (typeof playbookId !== "string") return null;

  const { data, error } = await client
    .from("playbooks")
    .select("action_type")
    .eq("id", playbookId)
    .maybeSingle();

  if (error || !data) return null;

  const actionType = (data as { action_type?: unknown }).action_type;
  return typeof actionType === "string" ? actionType : null;
}

// Outcome of one signed webhook attempt:
//   done   202 accepted, or 409 (n8n/database refused: replay, not approved,
//          already started); nothing more to do for this run
//   retry  502/503 or a network error: try again later
//   failed any other answer (e.g. 400/401): not retried
export type WebhookAttemptOutcome = "done" | "retry" | "failed";

export interface RemediationWebhookBody {
  playbook_run_id: string;
  incident_id: string;
  action_type: string;
  request_payload: Record<string, unknown>;
}

// One signed POST to n8n workflow 06, with a new nonce (every attempt is signed
// again). Shared by the immediate dispatch and the outbox worker.
export async function sendRemediationWebhook(
  config: RemediationWebhookConfig,
  payload: RemediationWebhookBody,
  fetchImpl: FetchFunction = fetch
): Promise<{ outcome: WebhookAttemptOutcome; status: string }> {
  const body = JSON.stringify(payload);
  const nonce = randomBytes(18).toString("base64url");
  const headers = buildSignedHeaders(config.signingSecret, { method: "POST", path: WEBHOOK_PATH, body, nonce });

  try {
    const response = await fetchImpl(config.url, {
      method: "POST",
      headers: { ...headers, "content-type": "application/json" },
      body,
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS)
    });
    const status = String(response.status);
    if (response.status === 202 || response.status === 409) return { outcome: "done", status };
    if (response.status === 502 || response.status === 503) return { outcome: "retry", status };
    return { outcome: "failed", status };
  } catch {
    // Do not log error details: they may contain sensitive request data.
    return { outcome: "retry", status: "network_error" };
  }
}

export function isRemediationAction(action: unknown): action is string {
  return typeof action === "string" && isAllowedAction(action);
}

export function createRemediationWebhookDispatcher(
  config: RemediationWebhookConfig,
  options: DispatcherOptions = {}
): RemediationWebhookDispatcher {
  const fetchImpl = options.fetchImpl ?? fetch;
  const sleep = options.sleep ?? defaultSleep;
  const log = options.log ?? ((runId, attempt, status) => {
    console.info("Remediation webhook attempt", {
      runId,
      attempt,
      status
    });
  });

  return {
    async dispatch(client, runId) {
      const run = await getPlaybookRunById(client, runId);

      if (!run || run.status !== "approved") {
        return;
      }

      // playbook_runs has no action_type column: the action belongs to the
      // run's playbook, so read it from there when the run row lacks it.
      const actionType =
        typeof run.action_type === "string"
          ? run.action_type
          : await getPlaybookActionType(client, run.playbook_id);

      if (
        typeof run.incident_id !== "string" ||
        typeof actionType !== "string" ||
        !isAllowedAction(actionType)
      ) {
        log(runId, 1, "invalid_run_data");
        return;
      }

      const payload: RemediationWebhookBody = {
        playbook_run_id: String(run.id),
        incident_id: run.incident_id,
        action_type: actionType,
        request_payload: (run.request_payload ?? {}) as Record<string, unknown>
      };

      for (let attempt = 1; attempt <= RETRY_DELAYS_MS.length + 1; attempt++) {
        const { outcome, status } = await sendRemediationWebhook(config, payload, fetchImpl);
        log(runId, attempt, status);

        if (outcome !== "retry") return;

        if (attempt <= RETRY_DELAYS_MS.length) {
          await sleep(RETRY_DELAYS_MS[attempt - 1]!);
        }
      }
      // Still not delivered: the outbox worker (dispatch-outbox.service.ts)
      // sends approved runs again until n8n starts them.
    }
  };
}