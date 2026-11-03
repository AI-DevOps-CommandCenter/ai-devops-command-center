import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  getDashboardSummaryController
} from "../controllers/dashboard.controller.js";

const router = Router();

// Require authentication for dashboard endpoints
router.use(authenticateToken);

// Dashboard summary endpoint
router.get("/summary", getDashboardSummaryController);

export default router;