import type { Request, Response } from "express";

import {
  createInvestigation,
  getInvestigationsByIncident,
  getInvestigationById,
  updateInvestigation
} from "../services/investigation.service.js";

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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
    } = req.body;

    if (!incident_id || !UUID_REGEX.test(incident_id)) {
      return res.status(400).json({
        success: false,
        message: "A valid incident_id is required."
      });
    }

    if (evidence !== undefined && !Array.isArray(evidence)) {
      return res.status(400).json({
        success: false,
        message: "Evidence must be an array."
      });
    }

    const { data, error } = await createInvestigation(
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

    if (error) {
      console.error("Create investigation error:", error);

      return res.status(400).json({
        success: false,
        message: "Unable to create investigation."
      });
    }

    return res.status(201).json({
      success: true,
      message: "Investigation created successfully.",
      data
    });
  } catch (error) {
    console.error("Investigation controller error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error."
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

    const incidentId = req.query.incident_id as string;

    if (!incidentId || !UUID_REGEX.test(incidentId)) {
      return res.status(400).json({
        success: false,
        message: "A valid incident_id query parameter is required."
      });
    }

    const { data, error } = await getInvestigationsByIncident(
      req.userSupabase,
      incidentId
    );

    if (error) {
      console.error("Get investigations error:", error);

      return res.status(500).json({
        success: false,
        message: "Unable to retrieve investigations."
      });
    }

    return res.status(200).json({
      success: true,
      message: "Investigations retrieved successfully.",
      data
    });
  } catch (error) {
    console.error("Get investigations controller error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error."
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

    const id = Array.isArray(req.params.id)
  ? req.params.id[0]
  : req.params.id;

    if (!UUID_REGEX.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid investigation ID."
      });
    }

    const { data, error } = await getInvestigationById(
      req.userSupabase,
      id
    );

    if (error) {
      return res.status(500).json({
        success: false,
        message: "Unable to retrieve investigation."
      });
    }

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
      message: "Internal server error."
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

    const id = Array.isArray(req.params.id)
  ? req.params.id[0]
  : req.params.id;

    if (!UUID_REGEX.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid investigation ID."
      });
    }

    const allowedFields = [
      "status",
      "summary",
      "root_cause",
      "evidence",
      "ai_model"
    ];

    const updates: Record<string, unknown> = {};

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        success: false,
        message: "Provide at least one field to update."
      });
    }

    if (
      updates.evidence !== undefined &&
      !Array.isArray(updates.evidence)
    ) {
      return res.status(400).json({
        success: false,
        message: "Evidence must be an array."
      });
    }

    const { data, error } = await updateInvestigation(
      req.userSupabase,
      id,
      updates
    );

    if (error) {
      console.error("Update investigation error:", error);

      return res.status(400).json({
        success: false,
        message: "Unable to update investigation."
      });
    }

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
    console.error("Update investigation controller error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error."
    });
  }
}