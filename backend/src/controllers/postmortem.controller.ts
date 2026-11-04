
import type { Request, Response } from "express";

import {
  createPostmortem,
  getPostmortems,
  getPostmortemById,
  updatePostmortem
} from "../services/postmortem.service.js";

import type {
  CreatePostmortemInput,
  UpdatePostmortemInput
} from "../services/postmortem.service.js";

import { getUserRole } from "../services/approval.service.js";
import { createAuditLog } from "../services/audit.service.js";

// UUID validation
const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isStringArray(value: unknown): boolean {
  return (
    Array.isArray(value) &&
    value.every(
      (item) =>
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item)
    )
  );
}

function isValidOptionalText(value: unknown): boolean {
  return value === undefined || typeof value === "string";
}

async function isIncidentManager(
  client: NonNullable<Request["userSupabase"]>,
  userId: string
): Promise<boolean> {
  const role = await getUserRole(client, userId);
  return ["admin", "operator"].includes(role);
}

// Create a postmortem
export async function createPostmortemController(
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

    if (!(await isIncidentManager(client, userId))) {
      return res.status(403).json({
        success: false,
        message: "Only administrators and operators can create postmortems."
      });
    }

    const {
      incident_id,
      summary,
      root_cause,
      impact,
      timeline,
      lessons_learned,
      action_items
    } = req.body;

    if (
      typeof incident_id !== "string" ||
      !uuidRegex.test(incident_id)
    ) {
      return res.status(400).json({
        success: false,
        message: "A valid incident ID is required."
      });
    }

    if (
      typeof summary !== "string" ||
      !summary.trim()
    ) {
      return res.status(400).json({
        success: false,
        message: "A postmortem summary is required."
      });
    }

    if (
      !isValidOptionalText(root_cause) ||
      !isValidOptionalText(impact) ||
      !isValidOptionalText(lessons_learned)
    ) {
      return res.status(400).json({
        success: false,
        message: "Root cause, impact, and lessons learned must be text."
      });
    }

    if (timeline !== undefined && !isStringArray(timeline)) {
      return res.status(400).json({
        success: false,
        message: "Timeline must be an array of JSON objects."
      });
    }

    if (action_items !== undefined && !isStringArray(action_items)) {
      return res.status(400).json({
        success: false,
        message: "Action items must be an array of JSON objects."
      });
    }

    const input: CreatePostmortemInput = {
      incident_id,
      summary: summary.trim(),
      root_cause,
      impact,
      timeline,
      lessons_learned,
      action_items
    };

    const postmortem = await createPostmortem(
      client,
      input,
      userId
    );

    try {
      await createAuditLog(
        client,
        {
          action: "POSTMORTEM_CREATED",
          entity_type: "postmortem",
          entity_id: postmortem.id,
          details: {
            incident_id,
            summary: postmortem.summary
          }
        },
        userId
      );
    } catch (auditError) {
      console.error("Postmortem creation audit error:", auditError);
    }

    return res.status(201).json({
      success: true,
      message: "Postmortem created successfully.",
      data: postmortem
    });
  } catch (error) {
    console.error("Create postmortem error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to create postmortem."
    });
  }
}

// Get all accessible postmortems
export async function getPostmortemsController(
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

    const { incident_id, limit, offset } = req.query;

    if (
      incident_id !== undefined &&
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

    const parsedLimit = limit === undefined ? 20 : Number(limit);
    const parsedOffset = offset === undefined ? 0 : Number(offset);

    if (
      !Number.isInteger(parsedLimit) ||
      parsedLimit < 1 ||
      parsedLimit > 100
    ) {
      return res.status(400).json({
        success: false,
        message: "Limit must be an integer between 1 and 100."
      });
    }

    if (!Number.isInteger(parsedOffset) || parsedOffset < 0) {
      return res.status(400).json({
        success: false,
        message: "Offset must be a non-negative integer."
      });
    }

    const postmortems = await getPostmortems(client, {
      incident_id: incident_id as string | undefined,
      limit: parsedLimit,
      offset: parsedOffset
    });

    return res.status(200).json({
      success: true,
      count: postmortems.length,
      data: postmortems
    });
  } catch (error) {
    console.error("Get postmortems error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve postmortems."
    });
  }
}

// Get one postmortem by ID
export async function getPostmortemByIdController(
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

    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid postmortem ID."
      });
    }

    const postmortem = await getPostmortemById(client, id);

    if (!postmortem) {
      return res.status(404).json({
        success: false,
        message: "Postmortem not found."
      });
    }

    return res.status(200).json({
      success: true,
      data: postmortem
    });
  } catch (error) {
    console.error("Get postmortem error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve postmortem."
    });
  }
}

// Update an existing postmortem
export async function updatePostmortemController(
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

    if (!(await isIncidentManager(client, userId))) {
      return res.status(403).json({
        success: false,
        message: "Only administrators and operators can update postmortems."
      });
    }

    const { id } = req.params;

    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid postmortem ID."
      });
    }

    const {
      summary,
      root_cause,
      impact,
      timeline,
      lessons_learned,
      action_items
    } = req.body;

    const input: UpdatePostmortemInput = {};

    if (summary !== undefined) {
      if (typeof summary !== "string" || !summary.trim()) {
        return res.status(400).json({
          success: false,
          message: "Summary must be non-empty text."
        });
      }
      input.summary = summary.trim();
    }

    if (root_cause !== undefined) {
      if (typeof root_cause !== "string") {
        return res.status(400).json({
          success: false,
          message: "Root cause must be text."
        });
      }
      input.root_cause = root_cause;
    }

    if (impact !== undefined) {
      if (typeof impact !== "string") {
        return res.status(400).json({
          success: false,
          message: "Impact must be text."
        });
      }
      input.impact = impact;
    }

    if (lessons_learned !== undefined) {
      if (typeof lessons_learned !== "string") {
        return res.status(400).json({
          success: false,
          message: "Lessons learned must be text."
        });
      }
      input.lessons_learned = lessons_learned;
    }

    if (timeline !== undefined) {
      if (!isStringArray(timeline)) {
        return res.status(400).json({
          success: false,
          message: "Timeline must be an array of JSON objects."
        });
      }
      input.timeline = timeline;
    }

    if (action_items !== undefined) {
      if (!isStringArray(action_items)) {
        return res.status(400).json({
          success: false,
          message: "Action items must be an array of JSON objects."
        });
      }
      input.action_items = action_items;
    }

    if (Object.keys(input).length === 0) {
      return res.status(400).json({
        success: false,
        message: "At least one field must be provided for update."
      });
    }

    const postmortem = await updatePostmortem(client, id, input);

    if (!postmortem) {
      return res.status(404).json({
        success: false,
        message: "Postmortem not found or not accessible."
      });
    }

    try {
      await createAuditLog(
        client,
        {
          action: "POSTMORTEM_UPDATED",
          entity_type: "postmortem",
          entity_id: postmortem.id,
          details: {
            incident_id: postmortem.incident_id,
            updated_fields: Object.keys(input)
          }
        },
        userId
      );
    } catch (auditError) {
      console.error("Postmortem update audit error:", auditError);
    }

    return res.status(200).json({
      success: true,
      message: "Postmortem updated successfully.",
      data: postmortem
    });
  } catch (error) {
    console.error("Update postmortem error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update postmortem."
    });
  }
}
