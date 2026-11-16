import { Router } from "express";

import { authenticateToken } from "../middleware/auth.js";

import {
  createIncidentController,
  getIncidentsController,
  getIncidentByIdController,
  updateIncidentController
} from "../controllers/incident.controller.js";
import { getRecommendationController, getRecoveryChecksController } from "../controllers/recommendation.controller.js";

const router = Router();

// All incident routes require authentication
router.use(authenticateToken);

// POST /api/incidents
// Create a new incident
router.post("/", createIncidentController);

// GET /api/incidents
// Retrieve incidents
router.get("/", getIncidentsController);

// GET /api/incidents/:id/recommendation (latest AI analysis + matching enabled playbooks)
router.get("/:id/recommendation", getRecommendationController);

// GET /api/incidents/:id/recovery-checks (newest first)
router.get("/:id/recovery-checks", getRecoveryChecksController);

router.get("/:id", getIncidentByIdController);

router.patch("/:id", updateIncidentController);

export default router;
