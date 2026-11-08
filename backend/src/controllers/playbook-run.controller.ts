import type { Request, Response } from "express";

import {
  requestPlaybookRun,
  getPlaybookRuns,
  getPlaybookRunById,
  cancelPlaybookRun,
  completePlaybookRun
} from "../services/playbook-run.service.js";

import {
  getApprovalByRunId,
  decideApproval
} from "../services/approval.service.js";

import { sendDbError } from "../lib/db-errors.js";

// Playbook run writes use the database workflow functions (decisions
// A2/A3/A4). Every run needs a human approval (A4), the database prevents
// duplicate active runs and duplicate execution, and it writes the audit
// entry itself, so no audit call is made here. Starting a run is reserved
// for n8n (machine endpoints, A5).

// UUID validation
const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const validStatuses = [
  "pending_approval",
  "approved",
  "running",
  "success",
  "failed",
  "rejected",
  "cancelled"
];

function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isOptionalText(value: unknown): value is string | null | undefined {
  return value === undefined || value === null || typeof value === "string";
}

function readRunId(req: Request): string | null {
  const { id } = req.params;
  return typeof id === "string" && uuidRegex.test(id) ? id : null;
}

// Create a playbook execution request (and its pending approval)
export async function createPlaybookRunController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;
    const userId = req.user?.id;

    if (!client || !userId) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const {
      playbook_id,
      incident_id,
      request_payload,
      idempotency_key
    } = req.body ?? {};

    if (typeof playbook_id !== "string" || !uuidRegex.test(playbook_id)) {
      return res.status(400).json({
        success: false,
        message: "A valid playbook ID is required."
      });
    }

    if (typeof incident_id !== "string" || !uuidRegex.test(incident_id)) {
      return res.status(400).json({
        success: false,
        message: "A valid incident ID is required."
      });
    }

    if (request_payload !== undefined && !isJsonObject(request_payload)) {
      return res.status(400).json({
        success: false,
        message: "Request payload must be a JSON object."
      });
    }

    if (idempotency_key !== undefined && typeof idempotency_key !== "string") {
      return res.status(400).json({
        success: false,
        message: "Idempotency key must be a string."
      });
    }

    const result = await requestPlaybookRun(client, {
      incident_id,
      playbook_id,
      idempotency_key,
      request_payload
    });

    const playbookRun = await getPlaybookRunById(client, result.run_id);

    return res.status(result.created ? 201 : 200).json({
      success: true,
      message: result.created
        ? "Playbook execution request created successfully."
        : "Playbook execution request already exists.",
      data: {
        ...(playbookRun ?? { id: result.run_id, status: result.status }),
        approval_id: result.approval_id
      }
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Create playbook run error:",
      "Failed to create playbook execution request."
    );
  }
}

// Get all accessible playbook runs
export async function getPlaybookRunsController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;

    if (!client) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const { status, incident_id } = req.query;

    if (
      status &&
      !validStatuses.includes(status as string)
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid playbook run status."
      });
    }

    if (
      incident_id &&
      (
        typeof incident_id !== "string" ||
        !uuidRegex.test(incident_id)
      )
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid incident ID."
      });
    }

    const runs = await getPlaybookRuns(client, {
      status: status as never,
      incident_id: incident_id as string | undefined
    });

    return res.status(200).json({
      success: true,
      count: runs.length,
      data: runs
    });

  } catch (error) {
    console.error("Get playbook runs error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve playbook execution requests."
    });
  }
}

// Get a single playbook run
export async function getPlaybookRunByIdController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;

    if (!client) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const id = readRunId(req);

    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Invalid playbook run ID."
      });
    }

    const run = await getPlaybookRunById(client, id);

    if (!run) {
      return res.status(404).json({
        success: false,
        message: "Playbook execution request not found."
      });
    }

    return res.status(200).json({
      success: true,
      data: run
    });

  } catch (error) {
    console.error("Get playbook run error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve playbook execution request."
    });
  }
}

// Admins and operators approve or reject requests (never their own).
// A run is decided through its linked approval: one approval path (A3).
export async function decidePlaybookRunController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;
    const userId = req.user?.id;

    if (!client || !userId) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const id = readRunId(req);

    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Invalid playbook run ID."
      });
    }

    const { status, comments } = req.body ?? {};

    if (status !== "approved" && status !== "rejected") {
      return res.status(400).json({
        success: false,
        message: "Status must be approved or rejected."
      });
    }

    if (!isOptionalText(comments)) {
      return res.status(400).json({
        success: false,
        message: "Comments must be a string."
      });
    }

    const approval = await getApprovalByRunId(client, id);

    if (!approval) {
      return res.status(404).json({
        success: false,
        message: "No approval request found for this playbook run."
      });
    }

    await decideApproval(client, approval.id, { status, comments });

    const run = await getPlaybookRunById(client, id);

    return res.status(200).json({
      success: true,
      message: `Playbook request ${status} successfully.`,
      data: run
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Decide playbook run error:",
      "Failed to decide playbook request."
    );
  }
}

// Cancel a run: the requester while it waits for approval; admins and
// operators (with a reason) once it is approved or running.
export async function cancelPlaybookRunController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;
    const userId = req.user?.id;

    if (!client || !userId) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const id = readRunId(req);

    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Invalid playbook run ID."
      });
    }

    const { reason } = req.body ?? {};

    if (!isOptionalText(reason)) {
      return res.status(400).json({
        success: false,
        message: "Reason must be a string."
      });
    }

    await cancelPlaybookRun(client, id, reason);

    const run = await getPlaybookRunById(client, id);

    return res.status(200).json({
      success: true,
      message: "Playbook execution request cancelled successfully.",
      data: run
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Cancel playbook run error:",
      "Failed to cancel playbook execution request."
    );
  }
}

// Manual completion of a running run by an admin or operator (A3-Q3).
// A reason is required and the override is audited by the database.
// n8n completes runs through the machine endpoint instead.
export async function completePlaybookRunController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;
    const userId = req.user?.id;

    if (!client || !userId) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const id = readRunId(req);

    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Invalid playbook run ID."
      });
    }

    const { status, result_payload, reason } = req.body ?? {};

    if (status !== "success" && status !== "failed") {
      return res.status(400).json({
        success: false,
        message: "Status must be success or failed."
      });
    }

    if (result_payload !== undefined && !isJsonObject(result_payload)) {
      return res.status(400).json({
        success: false,
        message: "Result payload must be a JSON object."
      });
    }

    if (typeof reason !== "string" || reason.trim().length < 5) {
      return res.status(400).json({
        success: false,
        message: "A reason of at least 5 characters is required to complete a run manually."
      });
    }

    await completePlaybookRun(client, id, {
      status,
      result_payload,
      reason
    });

    const run = await getPlaybookRunById(client, id);

    return res.status(200).json({
      success: true,
      message: "Playbook execution completed manually.",
      data: run
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Complete playbook run error:",
      "Failed to complete playbook execution."
    );
  }
}
