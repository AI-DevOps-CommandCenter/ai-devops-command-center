import type { Request, Response, NextFunction } from "express";

import {
  supabase,
  createUserSupabaseClient,
  type UserSupabaseClient
} from "../config/supabase.js";
import { getUserRole } from "../services/approval.service.js";

export const APP_ROLES = ["user", "admin", "operator"] as const;
export type AppRole = (typeof APP_ROLES)[number];

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        email?: string;
      };

      userSupabase?: UserSupabaseClient;

      // Set by requireRole(); read through the user's own JWT (RLS applies).
      userRole?: AppRole;
    }
  }
}

// Extract the token from "Authorization: Bearer <token>".
// The scheme is matched case-insensitively (RFC 6750); returns null when
// the header is missing, uses another scheme, or carries an empty token.
export function extractBearerToken(header: string | undefined): string | null {
  if (!header) {
    return null;
  }

  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  const token = match?.[1]?.trim();

  return token ? token : null;
}

// Verifies the caller's JWT with Supabase Auth (publishable key only) and
// attaches a per-request Supabase client that carries the same JWT, so every
// database call is subject to that user's RLS policies (decisions A1, D-002).
export async function authenticateToken(
  req: Request,
  res: Response,
  next: NextFunction
) {
  try {
    const token = extractBearerToken(req.headers.authorization);

    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Authentication token is required."
      });
    }

    // Verify the JWT with Supabase Auth
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data.user) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token."
      });
    }

    // Attach authenticated user details
    req.user = {
      id: data.user.id,
      email: data.user.email
    };

    // Attach a Supabase client carrying the user's JWT
    req.userSupabase = createUserSupabaseClient(token);

    next();

  } catch (error) {
    console.error("Authentication error:", error);

    return res.status(500).json({
      success: false,
      message: "Authentication failed."
    });
  }
}

function isAppRole(value: unknown): value is AppRole {
  return (
    typeof value === "string" &&
    (APP_ROLES as readonly string[]).includes(value)
  );
}

// Role guard for routes. Must run after authenticateToken.
// The role is read from `profiles` with the caller's own JWT client, never
// with a privileged key (decision D-002).
export function requireRole(...allowedRoles: AppRole[]) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    try {
      const role = await getUserRole(req.userSupabase, req.user.id);

      if (!isAppRole(role)) {
        return res.status(403).json({
          success: false,
          message: "User profile or valid role not found."
        });
      }

      if (!allowedRoles.includes(role)) {
        return res.status(403).json({
          success: false,
          message: "You do not have permission to perform this action."
        });
      }

      req.userRole = role;
      next();

    } catch (error) {
      // No visible profile row (PostgREST "0 rows" for .single()) means the
      // user has no usable role: forbidden, not a server error.
      if ((error as { code?: unknown } | null)?.code === "PGRST116") {
        return res.status(403).json({
          success: false,
          message: "User profile or valid role not found."
        });
      }

      console.error("Role verification error:", error);

      return res.status(500).json({
        success: false,
        message: "Unable to verify user permissions."
      });
    }
  };
}
