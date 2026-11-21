import type { Request, Response } from "express";

import {
  createInvestigation,
  getInvestigationsByIncident,
  getInvestigationById,
  updateInvestigation
} from "../services/investigation.service.js";

import type {
  InvestigationStatus,
  UpdateInvestigationInput
} from "../services/investigation.service.js";

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const VALID_STATUSES = [
  "pending",
  "running",
  "completed",
  "failed"
] as const satisfies readonly InvestigationStatus[];

function isValidStatus(
  value: unknown
): value is InvestigationStatus {
  return (
    typeof value === "string" &&
    (VALID_STATUSES as readonly string[]).includes(value)
  );
}

function isOptionalNullableString(
  value: unknown
): value is string | null | undefined {
  return (
    value === undefined ||
    value === null ||
    typeof value === "string"
  );
}

function getParamId(req: Request): string {
  const id = req.params.id;
  return Array.isArray(id) ? id[0] : id;
}

// Create an investigation
export async function createInvestigationController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const {
      incident_id,
      status,
      summary,
      root_cause,
      evidence,
      ai_model
    } = req.body ?? {};

    if (
      typeof incident_id !== "string" ||
      !UUID_REGEX.test(incident_id)
    ) {
      return res.status(400).json({
        success: false,
        message: "A valid incident_id is required."
      });
    }

    if (
      status !== undefined &&
      !isValidStatus(status)
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid investigation status."
      });
    }

    if (
      !isOptionalNullableString(summary) ||
      !isOptionalNullableString(root_cause) ||
      !isOptionalNullableString(ai_model)
    ) {
      return res.status(400).json({
        success: false,
        message: "Summary, root_cause and ai_model must be strings or null."
      });
    }

    if (
      evidence !== undefined &&
      !Array.isArray(evidence)
    ) {
      return res.status(400).json({
        success: false,
        message: "Evidence must be an array."
      });
    }

    const data = await createInvestigation(
      req.userSupabase,
      {
        incident_id,
        status,
        summary,
        root_cause,
        evidence,
        ai_model
      }
    );

    return res.status(201).json({
      success: true,
      message: "Investigation created successfully.",
      data
    });
  } catch (error) {
    console.error("Create investigation error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to create investigation."
    });
  }
}

// Get investigations for an incident
export async function getInvestigationsByIncidentController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const incidentId = req.query.incident_id;

    if (
      typeof incidentId !== "string" ||
      !UUID_REGEX.test(incidentId)
    ) {
      return res.status(400).json({
        success: false,
        message: "A valid incident_id query parameter is required."
      });
    }

    const data = await getInvestigationsByIncident(
      req.userSupabase,
      incidentId
    );

    return res.status(200).json({
      success: true,
      message: "Investigations retrieved successfully.",
      data
    });
  } catch (error) {
    console.error("Get investigations error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to retrieve investigations."
    });
  }
}

// Get investigation by ID
export async function getInvestigationByIdController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const id = getParamId(req);

    if (!id || !UUID_REGEX.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid investigation ID."
      });
    }

    const data = await getInvestigationById(
      req.userSupabase,
      id
    );

    if (!data) {
      return res.status(404).json({
        success: false,
        message: "Investigation not found."
      });
    }

    return res.status(200).json({
      success: true,
      message: "Investigation retrieved successfully.",
      data
    });
  } catch (error) {
    console.error("Get investigation error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to retrieve investigation."
    });
  }
}

// Update investigation
export async function updateInvestigationController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const id = getParamId(req);

    if (!id || !UUID_REGEX.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid investigation ID."
      });
    }

    const {
      status,
      summary,
      root_cause,
      evidence,
      ai_model
    } = req.body ?? {};

    const input: UpdateInvestigationInput = {};

    if (status !== undefined) {
      if (!isValidStatus(status)) {
        return res.status(400).json({
          success: false,
          message: "Invalid investigation status."
        });
      }

      input.status = status;
    }

    if (summary !== undefined) {
      if (!isOptionalNullableString(summary)) {
        return res.status(400).json({
          success: false,
          message: "Summary must be a string or null."
        });
      }

      input.summary = summary;
    }

    if (root_cause !== undefined) {
      if (!isOptionalNullableString(root_cause)) {
        return res.status(400).json({
          success: false,
          message: "Root cause must be a string or null."
        });
      }

      input.root_cause = root_cause;
    }

    if (evidence !== undefined) {
      if (!Array.isArray(evidence)) {
        return res.status(400).json({
          success: false,
          message: "Evidence must be an array."
        });
      }

      input.evidence = evidence;
    }

    if (ai_model !== undefined) {
      if (!isOptionalNullableString(ai_model)) {
        return res.status(400).json({
          success: false,
          message: "AI model must be a string or null."
        });
      }

      input.ai_model = ai_model;
    }

    if (Object.keys(input).length === 0) {
      return res.status(400).json({
        success: false,
        message: "Provide at least one valid field to update."
      });
    }

    const data = await updateInvestigation(
      req.userSupabase,
      id,
      input
    );

    if (!data) {
      return res.status(404).json({
        success: false,
        message: "Investigation not found."
      });
    }

    return res.status(200).json({
      success: true,
      message: "Investigation updated successfully.",
      data
    });
  } catch (error) {
    console.error("Update investigation error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to update investigation."
    });
  }
}
