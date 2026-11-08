import type { Request, Response } from "express";
import {
  getApprovals,
  getApprovalById,
  decideApproval,
  cancelApproval
} from "../services/approval.service.js";
import { requestPlaybookRun } from "../services/playbook-run.service.js";
import { sendDbError } from "../lib/db-errors.js";

// Approval writes use the database workflow functions (decisions A2/A3).
// The functions enforce who may decide (admin or operator, never their own
// request), and write the audit entry themselves, so no audit call is made
// here.

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const validStatuses = ["pending", "approved", "rejected", "cancelled"];

function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isOptionalText(value: unknown): value is string | null | undefined {
  return value === undefined || value === null || typeof value === "string";
}

// Request an approval. Under A3 every approval belongs to exactly one
// playbook run, so this creates the run and its pending approval together
// (request_playbook_run). `playbook_id` is therefore required.
export async function createApprovalController(
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

    const body = req.body ?? {};
    const { incident_id, playbook_id, request_payload, idempotency_key } = body;

    if (typeof incident_id !== "string" || !uuidRegex.test(incident_id)) {
      return res.status(400).json({
        success: false,
        message: "A valid incident ID is required."
      });
    }

    if (typeof playbook_id !== "string" || !uuidRegex.test(playbook_id)) {
      return res.status(400).json({
        success: false,
        message:
          "A valid playbook ID is required. Approvals are created together with a playbook run."
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

    const approval = result.approval_id
      ? await getApprovalById(client, result.approval_id)
      : null;

    return res.status(result.created ? 201 : 200).json({
      success: true,
      message: result.created
        ? "Approval request created successfully."
        : "Approval request already exists.",
      data: approval ?? {
        id: result.approval_id,
        playbook_run_id: result.run_id,
        status: "pending"
      }
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Create approval error:",
      "Failed to create approval request."
    );
  }
}

// Get all approval requests
export async function getApprovalsController(
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

    const { status } = req.query;

    if (status && !validStatuses.includes(status as string)) {
      return res.status(400).json({
        success: false,
        message: "Invalid approval status."
      });
    }

    const approvals = await getApprovals(client, status as string | undefined);

    return res.status(200).json({
      success: true,
      count: approvals.length,
      data: approvals
    });

  } catch (error) {
    console.error("Get approvals error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve approval requests."
    });
  }
}

// Get a single approval request
export async function getApprovalByIdController(
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

    const id = req.params.id;

    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid approval ID."
      });
    }

    const approval = await getApprovalById(client, id);

    if (!approval) {
      return res.status(404).json({
        success: false,
        message: "Approval request not found."
      });
    }

    return res.status(200).json({
      success: true,
      data: approval
    });

  } catch (error) {
    console.error("Get approval error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve approval request."
    });
  }
}

// Admin or operator approves or rejects a request (never their own).
// The database decides who is allowed (decide_approval); its message is
// returned with the matching status (403 own request / role, 409 already
// decided, 404 not found).
export async function decideApprovalController(
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

    const { id } = req.params;

    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid approval ID."
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

    await decideApproval(client, id, { status, comments });

    const approval = await getApprovalById(client, id);

    return res.status(200).json({
      success: true,
      message: `Approval request ${status} successfully.`,
      data: approval
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Decide approval error:",
      "Failed to decide approval request."
    );
  }
}

// The requester withdraws a pending request (its run is cancelled too).
export async function cancelApprovalController(
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

    const { id } = req.params;

    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid approval ID."
      });
    }

    const { reason } = req.body ?? {};

    if (!isOptionalText(reason)) {
      return res.status(400).json({
        success: false,
        message: "Reason must be a string."
      });
    }

    await cancelApproval(client, id, reason);

    const approval = await getApprovalById(client, id);

    return res.status(200).json({
      success: true,
      message: "Approval request cancelled successfully.",
      data: approval
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Cancel approval error:",
      "Failed to cancel approval request."
    );
  }
}
