import type { Request, Response } from "express";

import {
  createRemediationExecution,
  getRemediationExecutions,
  getRemediationExecutionById,
  updateRemediationExecution,
  type RemediationExecutionStatus
} from "../services/remediation-execution.service.js";

import { getUserRole } from "../services/approval.service.js";
import { createAuditLog } from "../services/audit.service.js";

const allowedStatuses: RemediationExecutionStatus[] = [
  "pending",
  "running",
  "succeeded",
  "failed",
  "cancelled"
];

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function hasManagerAccess(req: Request): Promise<boolean> {
  if (!req.user || !req.userSupabase) return false;

  const role = await getUserRole(req.userSupabase, req.user.id);

  return role === "admin" || role === "operator";
}

function isValidJsonObject(value: unknown): boolean {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value)
  );
}

function isValidDate(value: unknown): boolean {
  if (typeof value !== "string") return false;

  return !Number.isNaN(Date.parse(value));
}

// CREATE EXECUTION
export async function createRemediationExecutionController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({
        message: "Authentication required."
      });
    }

    if (!(await hasManagerAccess(req))) {
      return res.status(403).json({
        message: "Admin or operator access required."
      });
    }

    const { incident_id, playbook_id, input_data } = req.body ?? {};

    if (
      typeof incident_id !== "string" ||
      !uuidRegex.test(incident_id)
    ) {
      return res.status(400).json({
        message: "A valid incident_id is required."
      });
    }

    if (
      playbook_id !== undefined &&
      playbook_id !== null &&
      (typeof playbook_id !== "string" || !uuidRegex.test(playbook_id))
    ) {
      return res.status(400).json({
        message: "playbook_id must be a valid UUID or null."
      });
    }

    if (
      input_data !== undefined &&
      !isValidJsonObject(input_data)
    ) {
      return res.status(400).json({
        message: "input_data must be a JSON object."
      });
    }

    const data = await createRemediationExecution(
      req.userSupabase,
      {
        incident_id,
        playbook_id,
        input_data
      },
      req.user.id
    );

    try {
      await createAuditLog(
        req.userSupabase,
        {
          action: "REMEDIATION_EXECUTION_CREATED",
          entity_type: "remediation_execution",
          entity_id: data.id,
          details: {
            incident_id: data.incident_id,
            playbook_id: data.playbook_id,
            status: data.status
          }
        },
        req.user.id
      );
    } catch (auditError) {
      console.error("Remediation execution audit error:", auditError);
    }

    return res.status(201).json({
      message: "Remediation execution created successfully.",
      data
    });
  } catch (error) {
    console.error("Create remediation execution error:", error);

    return res.status(500).json({
      message: "Failed to create remediation execution."
    });
  }
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

// UPDATE EXECUTION
export async function updateRemediationExecutionController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({
        message: "Authentication required."
      });
    }

    if (!(await hasManagerAccess(req))) {
      return res.status(403).json({
        message: "Admin or operator access required."
      });
    }

    const idParam = req.params.id;
    const id = Array.isArray(idParam) ? idParam[0] : idParam;

    if (!id || !uuidRegex.test(id)) {
      return res.status(400).json({
        message: "A valid execution ID is required."
      });
    }

    const {
      status,
      output_data,
      started_at,
      completed_at,
      incident_id,
      playbook_id,
      triggered_by,
      input_data
    } = req.body ?? {};

    // Prevent changes to protected fields.
    if (
      incident_id !== undefined ||
      playbook_id !== undefined ||
      triggered_by !== undefined ||
      input_data !== undefined
    ) {
      return res.status(400).json({
        message: "Incident, playbook, requester and input data cannot be changed."
      });
    }

    if (
      status === undefined &&
      output_data === undefined &&
      started_at === undefined &&
      completed_at === undefined
    ) {
      return res.status(400).json({
        message: "Provide at least one field to update."
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

    if (
      output_data !== undefined &&
      !isValidJsonObject(output_data)
    ) {
      return res.status(400).json({
        message: "output_data must be a JSON object."
      });
    }

    if (
      started_at !== undefined &&
      started_at !== null &&
      !isValidDate(started_at)
    ) {
      return res.status(400).json({
        message: "started_at must be a valid date or null."
      });
    }

    if (
      completed_at !== undefined &&
      completed_at !== null &&
      !isValidDate(completed_at)
    ) {
      return res.status(400).json({
        message: "completed_at must be a valid date or null."
      });
    }

    const input = {
      ...(status !== undefined && { status }),
      ...(output_data !== undefined && { output_data }),
      ...(started_at !== undefined && { started_at }),
      ...(completed_at !== undefined && { completed_at })
    };

    const data = await updateRemediationExecution(
      req.userSupabase,
      id,
      input
    );

    if (!data) {
      return res.status(404).json({
        message: "Remediation execution not found."
      });
    }

    try {
      await createAuditLog(
        req.userSupabase,
        {
          action: "REMEDIATION_EXECUTION_UPDATED",
          entity_type: "remediation_execution",
          entity_id: id,
          details: {
            updated_fields: Object.keys(input),
            status: data.status
          }
        },
        req.user.id
      );
    } catch (auditError) {
      console.error("Remediation execution audit error:", auditError);
    }

    return res.status(200).json({
      message: "Remediation execution updated successfully.",
      data
    });
  } catch (error) {
    console.error("Update remediation execution error:", error);

    return res.status(500).json({
      message: "Failed to update remediation execution."
    });
  }
}
