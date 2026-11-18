import { Router, type Request, type Response } from "express";
import { rateLimit } from "express-rate-limit";

import { authenticateToken } from "../middleware/auth.js";
import {
  AssistantError,
  explainText,
  MAX_INPUT_LENGTH,
  type AssistantClient
} from "../services/assistant.service.js";

export interface AssistantRateLimit {
  windowMs: number;
  max: number;
}

// POST /api/assistant/explain  { text }  -> explanation of a log or error.
// Every signed-in user (user, operator, admin). assistant = null -> 503
// (GROQ_API_KEY not set). Per-user rate limit on top of the global /api one.
// The pasted text and the reply are never logged.
export function createAssistantRouter(assistant: AssistantClient | null, limits: AssistantRateLimit) {
  const router = Router();
  router.use(authenticateToken);

  const perUser = rateLimit({
    windowMs: limits.windowMs,
    limit: limits.max,
    standardHeaders: "draft-7",
    legacyHeaders: false,
    // authenticateToken ran first, so the user id is always set here.
    keyGenerator: (req) => `assistant:${req.user?.id ?? "unknown"}`,
    validate: { keyGeneratorIpFallback: false },
    handler: (_req, res) => {
      res.status(429).json({
        success: false,
        message: `Too many explanations. You can ask ${limits.max} times every ${Math.round(limits.windowMs / 60000)} minutes.`
      });
    }
  });

  router.post("/explain", (req: Request, res: Response, next) => {
    if (!assistant) {
      return res.status(503).json({
        success: false,
        message: "The developer assistant is not configured: GROQ_API_KEY is missing in backend/.env."
      });
    }
    return next();
  }, perUser, async (req: Request, res: Response) => {
    const text = (req.body as { text?: unknown } | undefined)?.text;
    if (typeof text !== "string" || text.trim() === "") {
      return res.status(400).json({ success: false, message: "Paste a log snippet or an error message." });
    }
    if (text.length > MAX_INPUT_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `The text is too long (max ${MAX_INPUT_LENGTH} characters).`
      });
    }

    try {
      const data = await explainText(assistant!, text);
      return res.status(200).json({ success: true, data });
    } catch (error) {
      if (error instanceof AssistantError) {
        // Only the kind is logged, never the text or the reply.
        console.error(`Developer assistant: ${error.kind}`);
        const status = error.kind === "timeout" ? 504 : error.kind === "rate_limited" ? 503 : 502;
        return res.status(status).json({ success: false, message: error.message });
      }
      console.error("Developer assistant: unexpected error");
      return res.status(500).json({ success: false, message: "Could not explain the text." });
    }
  });

  return router;
}
