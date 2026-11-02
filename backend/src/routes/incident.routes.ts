
import { Router } from "express";

import { authenticateToken } from "../middleware/auth.js";

import {
  createIncidentController,
  getIncidentsController,
  getIncidentByIdController,
  updateIncidentController
} from "../controllers/incident.controller.js";

const router = Router();

// All incident routes require authentication
router.use(authenticateToken);

// POST /api/incidents
// Create a new incident
router.post("/", createIncidentController);

// GET /api/incidents
// Retrieve incidents
router.get("/", getIncidentsController);

router.get("/:id", getIncidentByIdController);

router.patch("/:id", updateIncidentController);

export default router;
