import type { Request, Response } from "express";
import {
  getAuditLogs
} from "../services/audit.service.js";
import {
  getUserRole
} from "../services/approval.service.js";

export async function getAuditLogsController(
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

    // Only administrators can view audit logs
    const role = await getUserRole(client, userId);

    if (role !== "admin") {
      return res.status(403).json({
        success: false,
        message: "Only administrators can view audit logs."
      });
    }

    const action =
      typeof req.query.action === "string"
        ? req.query.action
        : undefined;

    const entity_type =
      typeof req.query.entity_type === "string"
        ? req.query.entity_type
        : undefined;

    const limit =
      typeof req.query.limit === "string"
        ? Number(req.query.limit)
        : 20;

    const offset =
      typeof req.query.offset === "string"
        ? Number(req.query.offset)
        : 0;

    // Validate pagination
    if (
      !Number.isInteger(limit) ||
      !Number.isInteger(offset) ||
      limit < 1 ||
      limit > 100 ||
      offset < 0
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid pagination values."
      });
    }

    const data = await getAuditLogs(client, {
      action,
      entity_type,
      limit,
      offset
    });

    return res.status(200).json({
      success: true,
      count: data.length,
      limit,
      offset,
      data
    });

  } catch (error) {
    console.error("Get audit logs error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve audit logs."
    });
  }
}