import { Router, type Request, type Response } from "express";
import { rateLimit } from "express-rate-limit";

import { authenticateToken, extractBearerToken } from "../middleware/auth.js";
import {
  InvalidRecoveryTokenError,
  PasswordRejectedError,
  PasswordResetRateLimitedError,
  type PasswordResetClient
} from "../services/password-reset.service.js";

// POST /api/auth/forgot-password  { email }      public; always the same answer
// POST /api/auth/reset-password   { password }   Bearer = recovery token from the email link
//
// client = null -> both answer 503 (Supabase not configured).

export const RESET_REQUEST_LIMIT = 5; // per IP and window
export const RESET_REQUEST_WINDOW_MS = 15 * 60 * 1000;
export const MIN_PASSWORD_LENGTH = 8;
const MAX_PASSWORD_LENGTH = 72; // bcrypt limit used by Supabase Auth
const EMAIL_PATTERN = /^[^\s@]{1,64}@[^\s@]{1,255}\.[^\s@]{1,63}$/;

const SENT_MESSAGE =
  "If an account exists for this email, a password reset link has been sent.";

export interface AuthRouterOptions {
  redirectTo: string;
  requestLimit?: number;
  requestWindowMs?: number;
}

export function createAuthRouter(client: PasswordResetClient | null, options: AuthRouterOptions) {
  const router = Router();

  const unavailable = (res: Response) =>
    res.status(503).json({ success: false, message: "Password reset is not available right now." });

  // Stricter than the general API limit. One limiter per route, so typos on
  // the new-password screen do not block reset emails (and the other way round).
  const limiter = (limit: number) => rateLimit({
    windowMs: options.requestWindowMs ?? RESET_REQUEST_WINDOW_MS,
    limit,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({ success: false, message: "Too many reset requests. Please try again later." });
    }
  });
  const emailLimiter = limiter(options.requestLimit ?? RESET_REQUEST_LIMIT); // every request sends an email
  const passwordLimiter = limiter(2 * (options.requestLimit ?? RESET_REQUEST_LIMIT));

  router.post("/forgot-password", emailLimiter, async (req: Request, res: Response) => {
    const email = typeof req.body?.email === "string" ? req.body.email.trim().toLowerCase() : "";
    if (!EMAIL_PATTERN.test(email)) {
      return res.status(400).json({ success: false, message: "Enter a valid email address." });
    }
    if (!client) return unavailable(res);
    try {
      await client.sendResetEmail(email, options.redirectTo);
    } catch (error) {
      if (error instanceof PasswordResetRateLimitedError) {
        return res.status(429).json({ success: false, message: "Too many reset emails. Please try again later." });
      }
      console.error("Password reset request failed:", error instanceof Error ? error.message : error);
      return unavailable(res);
    }
    return res.status(202).json({ success: true, message: SENT_MESSAGE });
  });

  router.post("/reset-password", passwordLimiter, authenticateToken, async (req: Request, res: Response) => {
    const password = req.body?.password;
    if (typeof password !== "string" || password.length < MIN_PASSWORD_LENGTH || password.length > MAX_PASSWORD_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `The password must be ${MIN_PASSWORD_LENGTH} to ${MAX_PASSWORD_LENGTH} characters long.`
      });
    }
    if (!client) return unavailable(res);
    const token = extractBearerToken(req.headers.authorization);
    try {
      await client.updatePassword(token!, password);
    } catch (error) {
      if (error instanceof InvalidRecoveryTokenError) {
        return res.status(401).json({ success: false, message: error.message });
      }
      if (error instanceof PasswordRejectedError) {
        return res.status(422).json({ success: false, message: error.message });
      }
      if (error instanceof PasswordResetRateLimitedError) {
        return res.status(429).json({ success: false, message: "Too many attempts. Please try again later." });
      }
      console.error("Password update failed:", error instanceof Error ? error.message : error);
      return unavailable(res);
    }
    return res.json({ success: true, message: "Your password has been changed. Sign in with the new password." });
  });

  return router;
}
