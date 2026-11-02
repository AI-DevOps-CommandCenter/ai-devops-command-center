
import type { Request, Response, NextFunction } from "express";

import {
  supabase,
  createUserSupabaseClient,
  type UserSupabaseClient
} from "../config/supabase.js";

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        email?: string;
      };

      userSupabase?: UserSupabaseClient;
    }
  }
}

export async function authenticateToken(
  req: Request,
  res: Response,
  next: NextFunction
) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Authentication token is required."
      });
    }

    const token = authHeader.substring(7);

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