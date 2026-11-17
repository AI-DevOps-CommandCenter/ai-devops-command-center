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
import {
  recordRecoveryCheck,
  RECOVERY_CHECK_STATUSES,
  type RecoveryCheckStatus
} from "../services/recovery-check.service.js";
import {
  recordAiAnalysis,
  AI_ACTIONS,
  AI_SEVERITIES
} from "../services/ai-analysis.service.js";
import {
  createIncidentFromAlert,
  getIncidentContext,
  savePostmortem,
  INCIDENT_SEVERITIES,
  type PostmortemReport
} from "../services/alert-intake.service.js";
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

// Webhook nonces share the database store with the n8n -> backend nonces; the
// prefix keeps the two directions apart. Same format as machine-auth.ts accepts,
// shortened so prefix + nonce fits consume_automation_nonce's 200 characters.
const WEBHOOK_NONCE_PREFIX = "webhook:";
const WEBHOOK_NONCE_PATTERN = /^[A-Za-z0-9_-]{16,192}$/;

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

  // POST /api/machine/remediation-nonces   (KI-1 / D-N8N-6)
  // Body: { nonce, signed_at }  = X-DC-Nonce and X-DC-Timestamp (unix seconds)
  // of the webhook request the BACKEND sent to n8n workflow 06. Workflow 06
  // calls this right after checking that request's HMAC and before starting
  // the run, so each webhook request is accepted once, atomically, in the
  // database (consume_automation_nonce), also when n8n runs executions in
  // parallel. 200 = first use, 409 = replay, 401 = outside the 5 minute window.
  router.post("/remediation-nonces", async (req: Request, res: Response) => {
    const { nonce, signed_at } = req.body ?? {};

    if (typeof nonce !== "string" || !WEBHOOK_NONCE_PATTERN.test(nonce)) {
      return res.status(400).json({ success: false, message: "A valid nonce is required." });
    }
    if (typeof signed_at !== "number" || !Number.isInteger(signed_at) || signed_at <= 0) {
      return res.status(400).json({ success: false, message: "signed_at must be the unix timestamp of the webhook request." });
    }

    const client = await getAutomationClient(deps.automation, res);
    if (!client) return;

    const { error } = await client.rpc("consume_automation_nonce", {
      p_nonce: WEBHOOK_NONCE_PREFIX + nonce,
      p_signed_at: new Date(signed_at * 1000).toISOString()
    });

    if (!error) {
      return res.status(200).json({ success: true, message: "Nonce accepted." });
    }
    resetSessionOnJwtError(deps.automation, error);
    if (error.code === "DC409") {
      return res.status(409).json({ success: false, message: "Replayed request (nonce already used)." });
    }
    if (error.code === "DC401") {
      return res.status(401).json({ success: false, message: "Signed request is outside the 5 minute window." });
    }
    return sendDbError(res, error, "Machine remediation nonce error:", "Failed to check the request nonce.");
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

  // POST /api/machine/recovery-checks  (BD-3, contract B.3; sent by n8n workflow 07)
  // Body: { incident_id, playbook_run_id, status, check_type?, details? }
  // status: pending | healthy | unhealthy | failed (recovery_checks_status_check)
  router.post("/recovery-checks", async (req: Request, res: Response) => {
    const body: unknown = req.body;
    if (!isJsonObject(body)) {
      return res.status(400).json({ success: false, message: "A JSON object body is required." });
    }
    const { incident_id, playbook_run_id, status, check_type, details } = body;

    if (typeof incident_id !== "string" || !uuidRegex.test(incident_id)) {
      return res.status(400).json({ success: false, message: "A valid incident_id is required." });
    }
    if (typeof playbook_run_id !== "string" || !uuidRegex.test(playbook_run_id)) {
      return res.status(400).json({ success: false, message: "A valid playbook_run_id is required." });
    }
    if (typeof status !== "string" || !(RECOVERY_CHECK_STATUSES as readonly string[]).includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Status must be one of: ${RECOVERY_CHECK_STATUSES.join(", ")}.`
      });
    }
    if (check_type !== undefined && check_type !== null && !isBoundedText(check_type, 100)) {
      return res.status(400).json({ success: false, message: "check_type must be 1 to 100 characters." });
    }
    if (details !== undefined && !isJsonObject(details)) {
      return res.status(400).json({ success: false, message: "Details must be a JSON object." });
    }

    const client = await getAutomationClient(deps.automation, res);
    if (!client) return;

    try {
      const recoveryCheckId = await recordRecoveryCheck(client, {
        incident_id,
        playbook_run_id,
        status: status as RecoveryCheckStatus,
        check_type: (check_type as string | null | undefined) ?? null,
        details: details as Record<string, unknown> | undefined
      });

      return res.status(201).json({
        success: true,
        message: "Recovery check recorded.",
        data: { recovery_check_id: recoveryCheckId }
      });
    } catch (error) {
      resetSessionOnJwtError(deps.automation, error);
      return sendDbError(res, error, "Machine record recovery check error:", "Failed to record recovery check.");
    }
  });

  // POST /api/machine/investigations/:id/analysis  (BD-2, contract B.3; sent by n8n workflow 05)
  // Body: { incident_id, summary, root_cause?, severity?, confidence?, evidence?, recommended_action?, model_name? }
  router.post("/investigations/:id/analysis", async (req: Request, res: Response) => {
    const investigationId = req.params.id;
    if (typeof investigationId !== "string" || !uuidRegex.test(investigationId)) {
      return res.status(400).json({ success: false, message: "A valid investigation id is required." });
    }
    const body: unknown = req.body;
    if (!isJsonObject(body)) {
      return res.status(400).json({ success: false, message: "A JSON object body is required." });
    }
    const { incident_id, summary, root_cause, severity, confidence, evidence, recommended_action, model_name } = body;

    if (typeof incident_id !== "string" || !uuidRegex.test(incident_id)) {
      return res.status(400).json({ success: false, message: "A valid incident_id is required." });
    }
    if (!isBoundedText(summary, 8000)) {
      return res.status(400).json({ success: false, message: "summary must be 1 to 8000 characters." });
    }
    if (root_cause !== undefined && root_cause !== null && !isBoundedText(root_cause, 8000)) {
      return res.status(400).json({ success: false, message: "root_cause must be 1 to 8000 characters." });
    }
    if (severity !== undefined && severity !== null &&
        (typeof severity !== "string" || !(AI_SEVERITIES as readonly string[]).includes(severity))) {
      return res.status(400).json({ success: false, message: `severity must be one of: ${AI_SEVERITIES.join(", ")}.` });
    }
    if (confidence !== undefined && confidence !== null &&
        (typeof confidence !== "number" || !Number.isFinite(confidence) || confidence < 0 || confidence > 1)) {
      return res.status(400).json({ success: false, message: "confidence must be a number from 0 to 1." });
    }
    if (evidence !== undefined && evidence !== null && !Array.isArray(evidence)) {
      return res.status(400).json({ success: false, message: "evidence must be an array." });
    }
    if (recommended_action !== undefined && recommended_action !== null &&
        (typeof recommended_action !== "string" || !(AI_ACTIONS as readonly string[]).includes(recommended_action))) {
      return res.status(400).json({ success: false, message: `recommended_action must be one of: ${AI_ACTIONS.join(", ")}.` });
    }
    if (model_name !== undefined && model_name !== null && !isBoundedText(model_name, 100)) {
      return res.status(400).json({ success: false, message: "model_name must be 1 to 100 characters." });
    }

    const client = await getAutomationClient(deps.automation, res);
    if (!client) return;

    try {
      const analysisId = await recordAiAnalysis(client, {
        incident_id,
        investigation_id: investigationId,
        model_name: (model_name as string | null | undefined) ?? null,
        summary,
        root_cause: (root_cause as string | null | undefined) ?? null,
        severity: (severity as string | null | undefined) ?? null,
        confidence: (confidence as number | null | undefined) ?? null,
        evidence: (evidence as unknown[] | null | undefined) ?? [],
        recommended_action: (recommended_action as string | null | undefined) ?? null
      });

      return res.status(201).json({
        success: true,
        message: "AI analysis recorded.",
        data: { analysis_id: analysisId }
      });
    } catch (error) {
      resetSessionOnJwtError(deps.automation, error);
      return sendDbError(res, error, "Machine record AI analysis error:", "Failed to record AI analysis.");
    }
  });

  // POST /api/machine/incidents  (BD-1; sent by n8n workflow 01)
  // Body: { fingerprint, title, severity, service_name, description?, environment?, detected_at? }
  // 201 when created, 200 when an active incident for the fingerprint already exists.
  router.post("/incidents", async (req: Request, res: Response) => {
    const body: unknown = req.body;
    if (!isJsonObject(body)) {
      return res.status(400).json({ success: false, message: "A JSON object body is required." });
    }
    const { fingerprint, title, description, severity, service_name, environment, detected_at } = body;

    if (!isBoundedText(fingerprint, 200)) {
      return res.status(400).json({ success: false, message: "fingerprint must be 1 to 200 characters." });
    }
    if (!isBoundedText(title, 300)) {
      return res.status(400).json({ success: false, message: "title must be 1 to 300 characters." });
    }
    if (typeof severity !== "string" || !(INCIDENT_SEVERITIES as readonly string[]).includes(severity)) {
      return res.status(400).json({ success: false, message: `severity must be one of: ${INCIDENT_SEVERITIES.join(", ")}.` });
    }
    if (!isBoundedText(service_name, 200)) {
      return res.status(400).json({ success: false, message: "service_name must be 1 to 200 characters." });
    }
    if (description !== undefined && description !== null && !isBoundedText(description, 4000)) {
      return res.status(400).json({ success: false, message: "description must be 1 to 4000 characters." });
    }
    if (environment !== undefined && environment !== null && !isBoundedText(environment, 100)) {
      return res.status(400).json({ success: false, message: "environment must be 1 to 100 characters." });
    }
    if (detected_at !== undefined && detected_at !== null &&
        (typeof detected_at !== "string" || Number.isNaN(Date.parse(detected_at)))) {
      return res.status(400).json({ success: false, message: "detected_at must be an ISO 8601 timestamp." });
    }

    const client = await getAutomationClient(deps.automation, res);
    if (!client) return;

    try {
      const result = await createIncidentFromAlert(client, {
        fingerprint,
        title,
        description: (description as string | null | undefined) ?? null,
        severity,
        service_name,
        environment: (environment as string | null | undefined) ?? null,
        detected_at: (detected_at as string | null | undefined) ?? null
      });
      return res.status(result.created ? 201 : 200).json({
        success: true,
        message: result.created ? "Incident created." : "Incident already exists for this alert.",
        data: result
      });
    } catch (error) {
      resetSessionOnJwtError(deps.automation, error);
      return sendDbError(res, error, "Machine create incident error:", "Failed to create incident.");
    }
  });

  // GET /api/machine/incidents/:id/context  (BD-4; read by n8n workflow 08)
  router.get("/incidents/:id/context", async (req: Request, res: Response) => {
    const { id } = req.params;
    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({ success: false, message: "Invalid incident ID." });
    }
    const client = await getAutomationClient(deps.automation, res);
    if (!client) return;

    try {
      const context = await getIncidentContext(client, id);
      return res.status(200).json({ success: true, data: context });
    } catch (error) {
      resetSessionOnJwtError(deps.automation, error);
      return sendDbError(res, error, "Machine incident context error:", "Failed to read incident context.");
    }
  });

  // POST /api/machine/incidents/:id/postmortem  (BD-4; sent by n8n workflow 08)
  // Body: the validated postmortem (automation/schemas/postmortem-output.schema.json).
  router.post("/incidents/:id/postmortem", async (req: Request, res: Response) => {
    const { id } = req.params;
    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({ success: false, message: "Invalid incident ID." });
    }
    const body: unknown = req.body;
    if (!isJsonObject(body)) {
      return res.status(400).json({ success: false, message: "A JSON object body is required." });
    }
    const textFields = ["title", "summary", "root_cause", "impact", "remediation", "recovery_result"] as const;
    for (const field of textFields) {
      if (!isBoundedText(body[field], 4000)) {
        return res.status(400).json({ success: false, message: `${field} must be 1 to 4000 characters.` });
      }
    }
    const listFields = ["evidence", "lessons_learned", "preventive_actions"] as const;
    for (const field of listFields) {
      const list = body[field];
      if (!Array.isArray(list) || list.length > 20 || !list.every((item) => isBoundedText(item, 500))) {
        return res.status(400).json({ success: false, message: `${field} must be a list of up to 20 texts.` });
      }
    }
    const timeline = body.timeline;
    if (!Array.isArray(timeline) || timeline.length > 50 || !timeline.every((entry) =>
        isJsonObject(entry) && isBoundedText(entry.time, 40) && isBoundedText(entry.event, 500))) {
      return res.status(400).json({ success: false, message: "timeline must be a list of { time, event }." });
    }

    const client = await getAutomationClient(deps.automation, res);
    if (!client) return;

    try {
      const postmortemId = await savePostmortem(client, id, body as unknown as PostmortemReport);
      return res.status(201).json({
        success: true,
        message: "Postmortem saved.",
        data: { postmortem_id: postmortemId }
      });
    } catch (error) {
      resetSessionOnJwtError(deps.automation, error);
      return sendDbError(res, error, "Machine save postmortem error:", "Failed to save postmortem.");
    }
  });

  return router;
}
