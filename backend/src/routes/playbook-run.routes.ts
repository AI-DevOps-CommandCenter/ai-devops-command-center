
import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  createPlaybookRunController,
  getPlaybookRunsController,
  getPlaybookRunByIdController,
  decidePlaybookRunController,
  updatePlaybookRunStatusController
} from "../controllers/playbook-run.controller.js";

const router = Router();

// All playbook run endpoints require authentication
router.use(authenticateToken);

// Create a playbook execution request
router.post("/", createPlaybookRunController);

// Get all accessible playbook runs
router.get("/", getPlaybookRunsController);

// Get a specific playbook run
router.get("/:id", getPlaybookRunByIdController);

// Approve or reject a playbook request
router.patch("/:id/decision", decidePlaybookRunController);

// Update execution status and results

export default router;
