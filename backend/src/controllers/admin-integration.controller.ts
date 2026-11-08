import type { Request, Response } from "express";
import {
  getAllIntegrations,
  createIntegration,
  updateIntegration,
  deleteIntegration
} from "../services/admin-integration.service.js";
import { getUserRole } from "../services/approval.service.js";
import { createAuditLog } from "../services/audit.service.js";

const allowedProviders = [
  "github",
  "gitlab",
  "slack",
  "discord",
  "prometheus",
  "grafana",
  "aws"
];

async function isAdmin(req: Request): Promise<boolean> {
  if (!req.userSupabase || !req.user) return false;

  const role = await getUserRole(req.userSupabase, req.user.id);
  return role === "admin";
}

export async function getIntegrationsController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({ message: "Authentication required." });
    }

    if (!(await isAdmin(req))) {
      return res.status(403).json({ message: "Admin access required." });
    }

    const data = await getAllIntegrations(req.userSupabase);
    return res.status(200).json({ data });
  } catch (error) {
    console.error("Get integrations error:", error);
    return res.status(500).json({ message: "Failed to retrieve integrations." });
  }
}

export async function createIntegrationController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({ message: "Authentication required." });
    }

    if (!(await isAdmin(req))) {
      return res.status(403).json({ message: "Admin access required." });
    }

    const { name, provider, is_active, settings } = req.body ?? {};

    if (typeof name !== "string" || !name.trim()) {
      return res.status(400).json({ message: "A valid name is required." });
    }

    if (
      typeof provider !== "string" ||
      !allowedProviders.includes(provider.toLowerCase())
    ) {
      return res.status(400).json({
        message: "Invalid provider.",
        allowedProviders
      });
    }

    if (is_active !== undefined && typeof is_active !== "boolean") {
      return res.status(400).json({ message: "is_active must be a boolean." });
    }

    if (
      settings !== undefined &&
      (settings === null || typeof settings !== "object" || Array.isArray(settings))
    ) {
      return res.status(400).json({ message: "settings must be a JSON object." });
    }

    const data = await createIntegration(
      req.userSupabase,
      {
        name: name.trim(),
        provider: provider.toLowerCase(),
        is_active,
        settings
      },
      req.user.id
    );

    try {
      await createAuditLog(
        req.userSupabase,
        {
          action: "INTEGRATION_CREATED",
          entity_type: "integration",
          entity_id: data.id,
          details: { name: data.name, provider: data.provider }
        },
        req.user.id
      );
    } catch (auditError) {
      console.error("Integration audit log error:", auditError);
    }

    return res.status(201).json({
      message: "Integration created successfully.",
      data
    });
  } catch (error) {
    console.error("Create integration error:", error);
    return res.status(500).json({ message: "Failed to create integration." });
  }
}

export async function updateIntegrationController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({ message: "Authentication required." });
    }

    if (!(await isAdmin(req))) {
      return res.status(403).json({ message: "Admin access required." });
    }

    const idParam = req.params.id;
    const id = Array.isArray(idParam) ? idParam[0] : idParam;

    if (!id || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
      return res.status(400).json({ message: "A valid integration ID is required." });
    }

    const { name, provider, is_active, settings } = req.body ?? {};

    if (
      name === undefined &&
      provider === undefined &&
      is_active === undefined &&
      settings === undefined
    ) {
      return res.status(400).json({ message: "Provide at least one field to update." });
    }

    if (name !== undefined && (typeof name !== "string" || !name.trim())) {
      return res.status(400).json({ message: "Name must be a non-empty string." });
    }

    if (
      provider !== undefined &&
      (typeof provider !== "string" ||
        !allowedProviders.includes(provider.toLowerCase()))
    ) {
      return res.status(400).json({ message: "Invalid provider." });
    }

    if (is_active !== undefined && typeof is_active !== "boolean") {
      return res.status(400).json({ message: "is_active must be a boolean." });
    }

    if (
      settings !== undefined &&
      (settings === null || typeof settings !== "object" || Array.isArray(settings))
    ) {
      return res.status(400).json({ message: "settings must be a JSON object." });
    }

    const input = {
      ...(name !== undefined && { name: name.trim() }),
      ...(provider !== undefined && { provider: provider.toLowerCase() }),
      ...(is_active !== undefined && { is_active }),
      ...(settings !== undefined && { settings })
    };

    const data = await updateIntegration(req.userSupabase, id, input);

    if (!data) {
      return res.status(404).json({ message: "Integration not found." });
    }

    try {
      await createAuditLog(
        req.userSupabase,
        {
          action: "INTEGRATION_UPDATED",
          entity_type: "integration",
          entity_id: id,
          details: { updated_fields: Object.keys(input) }
        },
        req.user.id
      );
    } catch (auditError) {
      console.error("Integration audit log error:", auditError);
    }

    return res.status(200).json({
      message: "Integration updated successfully.",
      data
    });
  } catch (error) {
    console.error("Update integration error:", error);
    return res.status(500).json({ message: "Failed to update integration." });
  }
}

export async function deleteIntegrationController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({ message: "Authentication required." });
    }

    if (!(await isAdmin(req))) {
      return res.status(403).json({ message: "Admin access required." });
    }

    const idParam = req.params.id;
    const id = Array.isArray(idParam) ? idParam[0] : idParam;

    if (!id || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
      return res.status(400).json({ message: "A valid integration ID is required." });
    }

    const deleted = await deleteIntegration(req.userSupabase, id);

    if (!deleted) {
      return res.status(404).json({ message: "Integration not found." });
    }

    try {
      await createAuditLog(
        req.userSupabase,
        {
          action: "INTEGRATION_DELETED",
          entity_type: "integration",
          entity_id: id
        },
        req.user.id
      );
    } catch (auditError) {
      console.error("Integration audit log error:", auditError);
    }

    return res.status(200).json({
      message: "Integration deleted successfully."
    });
  } catch (error) {
    console.error("Delete integration error:", error);
    return res.status(500).json({ message: "Failed to delete integration." });
  }
}
