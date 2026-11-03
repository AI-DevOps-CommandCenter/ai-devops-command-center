
import type { Request, Response } from "express";
import {
  createApproval,
  getApprovals,
  getApprovalById,
  getUserRole,
  decideApproval
} from "../services/approval.service.js";

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

    const { incident_id } = req.body;

    // Validate incident ID
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

    if (!incident_id || !uuidRegex.test(incident_id)) {
      return res.status(400).json({
        success: false,
        message: "A valid incident ID is required."
      });
    }

    const approval = await createApproval(
      client,
      { incident_id },
      userId
    );

    return res.status(201).json({
      success: true,
      message: "Approval request created successfully.",
      data: approval
    });

  } catch (error) {
    console.error("Create approval error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to create approval request."
    });
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

    const validStatuses = ["pending", "approved", "rejected"];

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

if (typeof id !== "string") {
  return res.status(400).json({
    success: false,
    message: "Invalid approval ID."
  });
}

    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

    if (!uuidRegex.test(id)) {
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
// Admin approves or rejects an approval request
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

    // Check whether the authenticated user is an admin
    const role = await getUserRole(client, userId);

    if (role !== "admin") {
      return res.status(403).json({
        success: false,
        message: "Only administrators can decide approval requests."
      });
    }

    const { id } = req.params;

    if (typeof id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid approval ID."
      });
    }

    const { status, comments } = req.body;

    if (!["approved", "rejected"].includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Status must be approved or rejected."
      });
    }

    if (comments !== undefined && comments !== null && typeof comments !== "string") {
      return res.status(400).json({
        success: false,
        message: "Comments must be a string."
      });
    }

    const approval = await decideApproval(
      client,
      id,
      { status, comments },
      userId
    );

    if (!approval) {
      return res.status(404).json({
        success: false,
        message: "Approval request not found, already decided, or you are not permitted to decide it."
      });
    }

    return res.status(200).json({
      success: true,
      message: `Approval request ${status} successfully.`,
      data: approval
    });

  } catch (error) {
    console.error("Decide approval error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to decide approval request."
    });
  }
}