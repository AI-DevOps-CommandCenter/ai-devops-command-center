import type { Request, Response } from "express";

import {
  getRemediationExecutions,
  getRemediationExecutionById,
  type RemediationExecutionStatus
} from "../services/remediation-execution.service.js";

// remediation_executions is legacy and read-only (decisions A2/A3; client
// writes revoked by migration 000700). Remediation is recorded as playbook
// runs, which require an approval before they can be executed.

const allowedStatuses: RemediationExecutionStatus[] = [
  "pending",
  "running",
  "succeeded",
  "failed",
  "cancelled"
];

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const LEGACY_READ_ONLY_MESSAGE =
  "Remediation executions are read-only legacy records. " +
  "Request remediation as a playbook run instead: POST /api/playbook-runs " +
  "(it needs an approval before it can run).";

// CREATE / UPDATE EXECUTION: no longer supported (410 Gone)
function legacyReadOnly(req: Request, res: Response) {
  if (!req.user || !req.userSupabase) {
    return res.status(401).json({
      message: "Authentication required."
    });
  }

  return res.status(410).json({
    success: false,
    message: LEGACY_READ_ONLY_MESSAGE
  });
}

export async function createRemediationExecutionController(
  req: Request,
  res: Response
) {
  return legacyReadOnly(req, res);
}

export async function updateRemediationExecutionController(
  req: Request,
  res: Response
) {
  return legacyReadOnly(req, res);
}

// LIST EXECUTIONS
export async function getRemediationExecutionsController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({
        message: "Authentication required."
      });
    }

    const { incident_id, playbook_id, status, limit, offset } = req.query;

    if (
      incident_id !== undefined &&
      (typeof incident_id !== "string" || !uuidRegex.test(incident_id))
    ) {
      return res.status(400).json({
        message: "Invalid incident_id."
      });
    }

    if (
      playbook_id !== undefined &&
      (typeof playbook_id !== "string" || !uuidRegex.test(playbook_id))
    ) {
      return res.status(400).json({
        message: "Invalid playbook_id."
      });
    }

    if (
      status !== undefined &&
      (typeof status !== "string" ||
        !allowedStatuses.includes(status as RemediationExecutionStatus))
    ) {
      return res.status(400).json({
        message: "Invalid execution status.",
        allowedStatuses
      });
    }

    const parsedLimit = limit === undefined ? 20 : Number(limit);
    const parsedOffset = offset === undefined ? 0 : Number(offset);

    if (
      !Number.isInteger(parsedLimit) ||
      parsedLimit < 1 ||
      parsedLimit > 100 ||
      !Number.isInteger(parsedOffset) ||
      parsedOffset < 0
    ) {
      return res.status(400).json({
        message: "Invalid pagination values. Limit must be 1–100 and offset must be 0 or greater."
      });
    }

    const data = await getRemediationExecutions(
      req.userSupabase,
      {
        incident_id: incident_id as string | undefined,
        playbook_id: playbook_id as string | undefined,
        status: status as RemediationExecutionStatus | undefined,
        limit: parsedLimit,
        offset: parsedOffset
      }
    );

    return res.status(200).json({
      count: data.length,
      limit: parsedLimit,
      offset: parsedOffset,
      data
    });
  } catch (error) {
    console.error("Get remediation executions error:", error);

    return res.status(500).json({
      message: "Failed to retrieve remediation executions."
    });
  }
}

// GET EXECUTION BY ID
export async function getRemediationExecutionByIdController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({
        message: "Authentication required."
      });
    }

    const idParam = req.params.id;
    const id = Array.isArray(idParam) ? idParam[0] : idParam;

    if (!id || !uuidRegex.test(id)) {
      return res.status(400).json({
        message: "A valid execution ID is required."
      });
    }

    const data = await getRemediationExecutionById(
      req.userSupabase,
      id
    );

    if (!data) {
      return res.status(404).json({
        message: "Remediation execution not found."
      });
    }

    return res.status(200).json({ data });
  } catch (error) {
    console.error("Get remediation execution error:", error);

    return res.status(500).json({
      message: "Failed to retrieve remediation execution."
    });
  }
}
