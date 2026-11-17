import { Router, type Request, type Response } from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  getServiceMetrics,
  listServiceHealth,
  MetricsUnavailableError,
  SERVICE_NAME_PATTERN,
  type PrometheusClient
} from "../services/metrics.service.js";

// GET /api/metrics/services            health of every scraped service
// GET /api/metrics/services/:service   current values + series (?window=15..360 min)
// prometheus = null -> the endpoints answer 503 (PROMETHEUS_URL not set).
export function createMetricsRouter(prometheus: PrometheusClient | null) {
  const router = Router();
  router.use(authenticateToken);

  const unavailable = (res: Response, message = "Metrics are not configured (PROMETHEUS_URL).") =>
    res.status(503).json({ success: false, message });

  async function handle(res: Response, fn: (p: PrometheusClient) => Promise<Response | void>) {
    if (!prometheus) return unavailable(res);
    try {
      return await fn(prometheus);
    } catch (error) {
      if (error instanceof MetricsUnavailableError) return unavailable(res, error.message);
      console.error("Metrics error:", error);
      return res.status(500).json({ success: false, message: "Failed to load metrics." });
    }
  }

  router.get("/services", (_req: Request, res: Response) =>
    handle(res, async (p) => {
      const data = await listServiceHealth(p);
      return res.json({ success: true, count: data.length, data });
    })
  );

  router.get("/services/:service", (req: Request, res: Response) => {
    const service = String(req.params.service ?? "");
    if (!SERVICE_NAME_PATTERN.test(service)) {
      return res.status(400).json({ success: false, message: "A valid service name is required." });
    }
    const rawWindow = req.query.window;
    const windowMinutes = rawWindow === undefined ? 60 : Number(rawWindow);
    if (!Number.isInteger(windowMinutes) || windowMinutes < 15 || windowMinutes > 360) {
      return res.status(400).json({ success: false, message: "window must be 15 to 360 minutes." });
    }
    return handle(res, async (p) => {
      const data = await getServiceMetrics(p, service, windowMinutes);
      if (!data) return res.status(404).json({ success: false, message: "Service not found in Prometheus." });
      return res.json({ success: true, data });
    });
  });

  return router;
}
