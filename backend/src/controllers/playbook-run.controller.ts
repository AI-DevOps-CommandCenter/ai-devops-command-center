import type { Request, Response } from "express";

import {
  createPlaybookRun,
  getPlaybookRuns,
  getPlaybookRunById,
  decidePlaybookRun,
  updatePlaybookRunStatus
} from "../services/playbook-run.service.js";

import {
  getUserRole
} from "../services/approval.service.js";

import {
  createAuditLog
} from "../services/audit.service.js";

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

// Create a playbook execution request
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
      request_payload
    } = req.body;

    if (!playbook_id || !uuidRegex.test(playbook_id)) {
      return res.status(400).json({
        success: false,
        message: "A valid playbook ID is required."
      });
    }

    if (!incident_id || !uuidRegex.test(incident_id)) {
      return res.status(400).json({
        success: false,
        message: "A valid incident ID is required."
      });
    }

    if (
      request_payload !== undefined &&
      (
        request_payload === null ||
        typeof request_payload !== "object" ||
        Array.isArray(request_payload)
      )
    ) {
      return res.status(400).json({
        success: false,
        message: "Request payload must be a JSON object."
      });
    }

    const playbookRun = await createPlaybookRun(
      client,
      {
        playbook_id,
        incident_id,
        request_payload
      },
      userId
    );

    if (!playbookRun) {
      return res.status(404).json({
        success: false,
        message: "Enabled playbook or accessible incident not found."
      });
    }

    try {
      await createAuditLog(
        client,
        {
          action: "PLAYBOOK_RUN_REQUESTED",
          entity_type: "playbook_run",
          entity_id: playbookRun.id,
          details: {
            playbook_id,
            incident_id,
            status: playbookRun.status
          }
        },
        userId
      );
    } catch (auditError) {
      console.error("Playbook request audit log error:", auditError);
    }

    return res.status(201).json({
      success: true,
      message: "Playbook execution request created successfully.",
      data: playbookRun
    });

  } catch (error) {
    console.error("Create playbook run error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to create playbook execution request."
    });
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

    const { id } = req.params;

    if (
      typeof id !== "string" ||
      !uuidRegex.test(id)
    ) {
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

// Admins and operators approve or reject requests
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

    const role = await getUserRole(client, userId);

    if (!["admin", "operator"].includes(role)) {
      return res.status(403).json({
        success: false,
        message: "Only administrators and operators can decide playbook requests."
      });
    }

    const { id } = req.params;

    if (
      typeof id !== "string" ||
      !uuidRegex.test(id)
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid playbook run ID."
      });
    }

    const { status } = req.body;

    if (!["approved", "rejected"].includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Status must be approved or rejected."
      });
    }

    const run = await decidePlaybookRun(
      client,
      id,
      { status },
      userId
    );

    if (!run) {
      return res.status(404).json({
        success: false,
        message: "Playbook request not found, already decided, or self-approval is not allowed."
      });
    }

    try {
      await createAuditLog(
        client,
        {
          action:
            status === "approved"
              ? "PLAYBOOK_RUN_APPROVED"
              : "PLAYBOOK_RUN_REJECTED",
          entity_type: "playbook_run",
          entity_id: run.id,
          details: {
            incident_id: run.incident_id,
            playbook_id: run.playbook_id
          }
        },
        userId
      );
    } catch (auditError) {
      console.error("Playbook decision audit log error:", auditError);
    }

    return res.status(200).json({
      success: true,
      message: `Playbook request ${status} successfully.`,
      data: run
    });

  } catch (error) {
    console.error("Decide playbook run error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to decide playbook request."
    });
  }
}

// Update execution status and results
export async function updatePlaybookRunStatusController(
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

    const role = await getUserRole(client, userId);

    if (!["admin", "operator"].includes(role)) {
      return res.status(403).json({
        success: false,
        message: "Only administrators and operators can update execution status."
      });
    }

    const { id } = req.params;

    if (
      typeof id !== "string" ||
      !uuidRegex.test(id)
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid playbook run ID."
      });
    }

    const { status, result_payload } = req.body;

    const allowedUpdates = [
      "running",
      "success",
      "failed",
      "cancelled"
    ];

    if (!allowedUpdates.includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Invalid execution status."
      });
    }

    if (
      result_payload !== undefined &&
      (
        result_payload === null ||
        typeof result_payload !== "object" ||
        Array.isArray(result_payload)
      )
    ) {
      return res.status(400).json({
        success: false,
        message: "Result payload must be a JSON object."
      });
    }

    const run = await updatePlaybookRunStatus(
      client,
      id,
      { status, result_payload }
    );

    if (!run) {
      return res.status(400).json({
        success: false,
        message: "Playbook run not found or invalid status transition."
      });
    }

    try {
      await createAuditLog(
        client,
        {
          action: "PLAYBOOK_RUN_STATUS_UPDATED",
          entity_type: "playbook_run",
          entity_id: run.id,
          details: {
            status: run.status,
            incident_id: run.incident_id
          }
        },
        userId
      );
    } catch (auditError) {
      console.error("Playbook status audit log error:", auditError);
    }

    return res.status(200).json({
      success: true,
      message: "Playbook execution status updated successfully.",
      data: run
    });

  } catch (error) {
    console.error("Update playbook status error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update playbook execution status."
    });
  }
}
