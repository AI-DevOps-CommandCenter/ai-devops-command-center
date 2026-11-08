import type { Request, Response } from "express";

import {
  getAllPlaybooks,
  createPlaybook,
  updatePlaybook,
  deletePlaybook
} from "../services/admin-playbook.service.js";

import type {
  PlaybookActionType,
  UpdatePlaybookInput
} from "../services/admin-playbook.service.js";

import { getUserRole } from "../services/approval.service.js";

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const VALID_ACTION_TYPES = [
  "restart",
  "circuit_breaker",
  "rollback",
  "scale"
] as const satisfies readonly PlaybookActionType[];

function isValidActionType(
  value: unknown
): value is PlaybookActionType {
  return (
    typeof value === "string" &&
    (VALID_ACTION_TYPES as readonly string[]).includes(value)
  );
}

function isPlainObject(
  value: unknown
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}

async function isAdmin(req: Request): Promise<boolean> {
  if (!req.userSupabase || !req.user) return false;

  const role = await getUserRole(
    req.userSupabase,
    req.user.id
  );

  return role === "admin";
}

// GET /api/admin/playbooks
export async function getAllPlaybooksController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase || !req.user) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    if (!(await isAdmin(req))) {
      return res.status(403).json({
        success: false,
        message: "Only admins can manage playbooks."
      });
    }

    const playbooks = await getAllPlaybooks(
      req.userSupabase
    );

    return res.status(200).json({
      success: true,
      count: playbooks.length,
      data: playbooks
    });
  } catch (error) {
    console.error("Get playbooks error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve playbooks."
    });
  }
}

// POST /api/admin/playbooks
export async function createPlaybookController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase || !req.user) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    if (!(await isAdmin(req))) {
      return res.status(403).json({
        success: false,
        message: "Only admins can create playbooks."
      });
    }

    const {
      name,
      description,
      action_type,
      configuration,
      enabled,
      requires_approval
    } = req.body ?? {};

    if (typeof name !== "string" || !name.trim()) {
      return res.status(400).json({
        success: false,
        message: "Playbook name is required."
      });
    }

    if (!isValidActionType(action_type)) {
      return res.status(400).json({
        success: false,
        message: "Invalid action type."
      });
    }

    if (
      description !== undefined &&
      description !== null &&
      typeof description !== "string"
    ) {
      return res.status(400).json({
        success: false,
        message: "Description must be a string."
      });
    }

    if (
      configuration !== undefined &&
      !isPlainObject(configuration)
    ) {
      return res.status(400).json({
        success: false,
        message: "Configuration must be a JSON object."
      });
    }

    if (
      enabled !== undefined &&
      typeof enabled !== "boolean"
    ) {
      return res.status(400).json({
        success: false,
        message: "Enabled must be true or false."
      });
    }

    if (
      requires_approval !== undefined &&
      typeof requires_approval !== "boolean"
    ) {
      return res.status(400).json({
        success: false,
        message: "Requires_approval must be true or false."
      });
    }

    const playbook = await createPlaybook(
      req.userSupabase,
      {
        name: name.trim(),
        description,
        action_type,
        configuration,
        enabled,
        requires_approval
      }
    );

    return res.status(201).json({
      success: true,
      message: "Playbook created successfully.",
      data: playbook
    });
  } catch (error) {
    console.error("Create playbook error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to create playbook."
    });
  }
}

// PATCH /api/admin/playbooks/:id
export async function updatePlaybookController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase || !req.user) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    if (!(await isAdmin(req))) {
      return res.status(403).json({
        success: false,
        message: "Only admins can update playbooks."
      });
    }

    const idParam = req.params.id;
    const id = Array.isArray(idParam)
      ? idParam[0]
      : idParam;

    if (!id || !UUID_REGEX.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid playbook ID."
      });
    }

    const {
      name,
      description,
      action_type,
      configuration,
      enabled,
      requires_approval
    } = req.body ?? {};

    const input: UpdatePlaybookInput = {};

    if (name !== undefined) {
      if (typeof name !== "string" || !name.trim()) {
        return res.status(400).json({
          success: false,
          message: "Name must be a non-empty string."
        });
      }

      input.name = name.trim();
    }

    if (description !== undefined) {
      if (
        description !== null &&
        typeof description !== "string"
      ) {
        return res.status(400).json({
          success: false,
          message: "Description must be a string or null."
        });
      }

      input.description = description;
    }

    if (action_type !== undefined) {
      if (!isValidActionType(action_type)) {
        return res.status(400).json({
          success: false,
          message: "Invalid action type."
        });
      }

      input.action_type = action_type;
    }

    if (configuration !== undefined) {
      if (!isPlainObject(configuration)) {
        return res.status(400).json({
          success: false,
          message: "Configuration must be a JSON object."
        });
      }

      input.configuration = configuration;
    }

    if (enabled !== undefined) {
      if (typeof enabled !== "boolean") {
        return res.status(400).json({
          success: false,
          message: "Enabled must be true or false."
        });
      }

      input.enabled = enabled;
    }

    if (requires_approval !== undefined) {
      if (typeof requires_approval !== "boolean") {
        return res.status(400).json({
          success: false,
          message: "Requires_approval must be true or false."
        });
      }

      input.requires_approval = requires_approval;
    }

    if (Object.keys(input).length === 0) {
      return res.status(400).json({
        success: false,
        message: "At least one field must be provided."
      });
    }

    const playbook = await updatePlaybook(
      req.userSupabase,
      id,
      input
    );

    if (!playbook) {
      return res.status(404).json({
        success: false,
        message: "Playbook not found."
      });
    }

    return res.status(200).json({
      success: true,
      message: "Playbook updated successfully.",
      data: playbook
    });
  } catch (error) {
    console.error("Update playbook error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update playbook."
    });
  }
}

// DELETE /api/admin/playbooks/:id
export async function deletePlaybookController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase || !req.user) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    if (!(await isAdmin(req))) {
      return res.status(403).json({
        success: false,
        message: "Only admins can delete playbooks."
      });
    }

    const idParam = req.params.id;
    const id = Array.isArray(idParam)
      ? idParam[0]
      : idParam;

    if (!id || !UUID_REGEX.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid playbook ID."
      });
    }
    const result = await deletePlaybook(
      req.userSupabase,
      id
    );

    if (!result) {
      return res.status(404).json({
        success: false,
        message: "Playbook not found."
      });
    }

    return res.status(200).json({
      success: true,
      message: "Playbook deleted successfully."
    });
  } catch (error) {
    console.error("Delete playbook error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to delete playbook."
    });
  }
}
