import express, { Router, type Request, type Response } from "express";

import {
  captureRawBody,
  createDatabaseNonceStore,
  machineAuth,
  type NonceStore,
  type RpcClient
} from "../middleware/machine-auth.js";
import type { AutomationClientProvider } from "../config/machine.js";
import type { UserSupabaseClient } from "../config/supabase.js";
import {
  startPlaybookRun,
  completePlaybookRun
} from "../services/playbook-run.service.js";
import { sendDbError } from "../lib/db-errors.js";

// n8n -> backend machine endpoints (decision A5).
//
// Every request must be signed (machineAuth: HMAC-SHA256 over timestamp,
// nonce, method, path and raw body; 5 minute window; each nonce once).
// The path that is signed is the full request path, e.g.
// /api/machine/playbook-runs/<id>/start.
// The database call is made as the automation identity; the database
// functions accept only that role and never let it decide approvals.

export interface MachineDeps {
  signingSecret: string;
  automation: AutomationClientProvider;
  nonceStore?: NonceStore;
  now?: () => Date;
}

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isBoundedText(value: unknown, max: number): value is string {
  return typeof value === "string" && value.length >= 1 && value.length <= max;
}

// Replay protection backed by the database (consume_automation_nonce), so it
// also holds across backend instances. Created lazily: the automation
// identity signs in on the first machine request.
function lazyDatabaseNonceStore(automation: AutomationClientProvider): NonceStore {
  return {
    async consume(nonce, signedAt) {
      const client = await automation.get();
      return createDatabaseNonceStore(client as unknown as RpcClient).consume(nonce, signedAt);
    }
  };
}

// A revoked or expired automation session must lead to a fresh sign-in.
function resetSessionOnJwtError(automation: AutomationClientProvider, error: unknown) {
  const code = (error as { code?: unknown } | null)?.code;
  if (typeof code === "string" && code.startsWith("PGRST30")) {
    automation.invalidate();
  }
}

async function getAutomationClient(
  automation: AutomationClientProvider,
  res: Response
): Promise<UserSupabaseClient | null> {
  try {
    return await automation.get();
  } catch {
    res.status(503).json({
      success: false,
      message: "Automation identity is unavailable."
    });
    return null;
  }
}

export function createMachineRouter(deps: MachineDeps | null): Router {
  const router = Router();

  if (!deps) {
    router.use((_req, res) => {
      res.status(503).json({
        success: false,
        message: "Machine endpoints are not configured."
      });
    });
    return router;
  }

  router.use(express.json({ verify: captureRawBody, limit: "100kb" }));
  router.use(
    machineAuth({
      secret: deps.signingSecret,
      nonceStore: deps.nonceStore ?? lazyDatabaseNonceStore(deps.automation),
      now: deps.now
    })
  );

  // POST /api/machine/playbook-runs/:id/start
  // Body: { n8n_execution_id, workflow_name? }
  router.post("/playbook-runs/:id/start", async (req: Request, res: Response) => {
    const { id } = req.params;
    const { n8n_execution_id, workflow_name } = req.body ?? {};

    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({ success: false, message: "Invalid playbook run ID." });
    }
    if (!isBoundedText(n8n_execution_id, 200)) {
      return res.status(400).json({ success: false, message: "A valid n8n_execution_id is required." });
    }
    if (workflow_name !== undefined && !isBoundedText(workflow_name, 100)) {
      return res.status(400).json({ success: false, message: "Invalid workflow_name." });
    }

    const client = await getAutomationClient(deps.automation, res);
    if (!client) return;

    try {
      const data = await startPlaybookRun(client, id, n8n_execution_id, workflow_name);

      return res.status(200).json({
        success: true,
        message: "Playbook run started.",
        data
      });
    } catch (error) {
      resetSessionOnJwtError(deps.automation, error);
      return sendDbError(res, error, "Machine start playbook run error:", "Failed to start playbook run.");
    }
  });

  // POST /api/machine/playbook-runs/:id/complete
  // Body: { n8n_execution_id, status: "success" | "failed", result? }
  router.post("/playbook-runs/:id/complete", async (req: Request, res: Response) => {
    const { id } = req.params;
    const { n8n_execution_id, status, result } = req.body ?? {};

    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({ success: false, message: "Invalid playbook run ID." });
    }
    if (!isBoundedText(n8n_execution_id, 200)) {
      return res.status(400).json({ success: false, message: "A valid n8n_execution_id is required." });
    }
    if (status !== "success" && status !== "failed") {
      return res.status(400).json({ success: false, message: "Status must be success or failed." });
    }
    if (result !== undefined && !isJsonObject(result)) {
      return res.status(400).json({ success: false, message: "Result must be a JSON object." });
    }

    const client = await getAutomationClient(deps.automation, res);
    if (!client) return;

    try {
      const data = await completePlaybookRun(client, id, {
        status,
        result_payload: result,
        n8n_execution_id
      });

      return res.status(200).json({
        success: true,
        message: "Playbook run completed.",
        data
      });
    } catch (error) {
      resetSessionOnJwtError(deps.automation, error);
      return sendDbError(res, error, "Machine complete playbook run error:", "Failed to complete playbook run.");
    }
  });

  return router;
}
