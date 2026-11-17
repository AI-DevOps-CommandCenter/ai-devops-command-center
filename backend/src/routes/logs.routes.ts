import { Router, type Request, type Response } from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  getServiceLogs,
  LOG_SERVICE_PATTERN,
  LogsUnavailableError,
  type LokiClient
} from "../services/logs.service.js";

// GET /api/logs/services/:service?minutes=15&level=errors|all&limit=100
// loki = null -> 503 (LOKI_URL not set).
export function createLogsRouter(loki: LokiClient | null) {
  const router = Router();
  router.use(authenticateToken);

  router.get("/services/:service", async (req: Request, res: Response) => {
    if (!loki) {
      return res.status(503).json({ success: false, message: "Logs are not configured (LOKI_URL)." });
    }
    const service = String(req.params.service ?? "");
    if (!LOG_SERVICE_PATTERN.test(service)) {
      return res.status(400).json({ success: false, message: "A valid service name is required." });
    }
    const minutes = req.query.minutes === undefined ? 15 : Number(req.query.minutes);
    const limit = req.query.limit === undefined ? 100 : Number(req.query.limit);
    const level = req.query.level === undefined ? "errors" : String(req.query.level);
    if (!Number.isInteger(minutes) || minutes < 1 || minutes > 360) {
      return res.status(400).json({ success: false, message: "minutes must be 1 to 360." });
    }
    if (!Number.isInteger(limit) || limit < 1 || limit > 500) {
      return res.status(400).json({ success: false, message: "limit must be 1 to 500." });
    }
    if (level !== "errors" && level !== "all") {
      return res.status(400).json({ success: false, message: "level must be errors or all." });
    }
    try {
      const data = await getServiceLogs(loki, service, { minutes, limit, errorsOnly: level === "errors" });
      return res.json({ success: true, count: data.length, data });
    } catch (error) {
      if (error instanceof LogsUnavailableError) {
        return res.status(503).json({ success: false, message: error.message });
      }
      console.error("Logs error:", error);
      return res.status(500).json({ success: false, message: "Failed to load logs." });
    }
  });

  return router;
}
