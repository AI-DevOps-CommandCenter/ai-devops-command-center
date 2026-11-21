import type { Request, Response } from "express";

import { getRecommendation, getRecoveryChecks } from "../services/recommendation.service.js";
import { sendDbError } from "../lib/db-errors.js";

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// GET /api/incidents/:id/recommendation
// Latest AI analysis of the incident and the enabled playbooks whose
// action_type matches its recommended_action (mobile S17). The action itself
// still needs a request (POST /api/playbook-runs) and a human approval.
export async function getRecommendationController(req: Request, res: Response) {
  if (!req.userSupabase) {
    return res.status(401).json({ success: false, message: "Authentication required." });
  }
  const raw = req.params.id;
  const id = Array.isArray(raw) ? raw[0] : raw;
  if (typeof id !== "string" || !UUID_REGEX.test(id)) {
    return res.status(400).json({ success: false, message: "Invalid incident ID." });
  }

  try {
    const data = await getRecommendation(req.userSupabase, id);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    return sendDbError(res, error, "Get recommendation error:", "Failed to load the recommendation.");
  }
}

// GET /api/incidents/:id/recovery-checks (mobile S20), newest first.
export async function getRecoveryChecksController(req: Request, res: Response) {
  if (!req.userSupabase) {
    return res.status(401).json({ success: false, message: "Authentication required." });
  }
  const raw = req.params.id;
  const id = Array.isArray(raw) ? raw[0] : raw;
  if (typeof id !== "string" || !UUID_REGEX.test(id)) {
    return res.status(400).json({ success: false, message: "Invalid incident ID." });
  }

  try {
    const data = await getRecoveryChecks(req.userSupabase, id);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    return sendDbError(res, error, "Get recovery checks error:", "Failed to load recovery checks.");
  }
}
