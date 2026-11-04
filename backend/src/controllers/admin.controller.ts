import type { Request, Response } from "express";
import {
  getUsers,
  updateUserRole
} from "../services/admin.service.js";
import { getUserRole } from "../services/approval.service.js";
import { createAuditLog } from "../services/audit.service.js";

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const VALID_ROLES = ["admin", "operator", "user"];

// Check whether the current user is an admin
async function isAdmin(req: Request): Promise<boolean> {
  if (!req.userSupabase || !req.user) return false;

  const role = await getUserRole(req.userSupabase, req.user.id);
  return role === "admin";
}

// GET /api/admin/users
export async function getUsersController(
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
        message: "Only admins can view all users."
      });
    }

    const role = req.query.role as string | undefined;
    const limitValue = req.query.limit as string | undefined;
    const offsetValue = req.query.offset as string | undefined;

    if (role && !VALID_ROLES.includes(role)) {
      return res.status(400).json({
        success: false,
        message: "Invalid role filter."
      });
    }

    const limit = limitValue === undefined ? 20 : Number(limitValue);
    const offset = offsetValue === undefined ? 0 : Number(offsetValue);

    if (
      !Number.isInteger(limit) ||
      limit < 1 ||
      limit > 100 ||
      !Number.isInteger(offset) ||
      offset < 0
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid pagination values."
      });
    }

    const users = await getUsers(req.userSupabase, {
      role: role as "admin" | "operator" | "user" | undefined,
      limit,
      offset
    });

    return res.status(200).json({
      success: true,
      count: users.length,
      data: users
    });

  } catch (error) {
    console.error("Get users error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve users."
    });
  }
}

// PATCH /api/admin/users/:id/role
export async function updateUserRoleController(
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
        message: "Only admins can change user roles."
      });
    }

    const idParam = req.params.id;
    const id = Array.isArray(idParam) ? idParam[0] : idParam;
    const { role } = req.body;

    if (!id) {
    return res.status(400).json({
        success: false,
        message: "User ID is required."
    });
    }

    if (!UUID_REGEX.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID."
      });
    }

    if (typeof role !== "string" || !VALID_ROLES.includes(role)) {
      return res.status(400).json({
        success: false,
        message: "Role must be admin, operator, or user."
      });
    }

    if (id === req.user.id) {
      return res.status(400).json({
        success: false,
        message: "You cannot change your own role."
      });
    }

    await updateUserRole(req.userSupabase, id, {
      role: role as "admin" | "operator" | "user"
    });

    // Best-effort audit logging
    try {
      await createAuditLog(
        req.userSupabase,
        {
          action: "USER_ROLE_UPDATED",
          entity_type: "profile",
          entity_id: id,
          details: {
            new_role: role
          }
        },
        req.user.id
      );
    } catch (auditError) {
      console.error("Role update audit error:", auditError);
    }

    return res.status(200).json({
      success: true,
      message: "User role updated successfully."
    });

  } catch (error) {
    console.error("Update user role error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update user role."
    });
  }
}