import type { RequestHandler } from "express";
import cors from "cors";
import helmet from "helmet";
import { rateLimit } from "express-rate-limit";

import type { ServerConfig } from "../config/env.js";

// Security headers. This service is a JSON API (no HTML pages), so Helmet's
// defaults are appropriate.
export function securityHeaders(): RequestHandler {
  return helmet();
}

// CORS restricted to an explicit allow-list (CORS_ORIGINS).
// - Requests without an Origin header (native mobile apps, curl, server-to-
//   server) are not affected by CORS and are allowed through.
// - Browser requests from origins not on the list receive no CORS headers,
//   so the browser blocks them.
export function restrictedCors(allowedOrigins: string[]): RequestHandler {
  const allowList = new Set(allowedOrigins);

  return cors({
    origin(origin, callback) {
      if (!origin || allowList.has(origin)) {
        callback(null, true);
        return;
      }

      callback(null, false);
    },
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Authorization", "Content-Type"],
    maxAge: 600
  });
}

// Per-IP rate limiting for the API. Responses keep the API's JSON shape.
export function apiRateLimiter(
  config: Pick<ServerConfig, "rateLimitWindowMs" | "rateLimitMax">
): RequestHandler {
  return rateLimit({
    windowMs: config.rateLimitWindowMs,
    limit: config.rateLimitMax,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({
        success: false,
        message: "Too many requests. Please try again later."
      });
    }
  });
}
