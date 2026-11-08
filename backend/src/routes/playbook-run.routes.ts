import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  createPlaybookRunController,
  getPlaybookRunsController,
  getPlaybookRunByIdController,
  decidePlaybookRunController,
  cancelPlaybookRunController,
  completePlaybookRunController
} from "../controllers/playbook-run.controller.js";

const router = Router();

// All playbook run endpoints require authentication
router.use(authenticateToken);

// Create a playbook execution request (creates its pending approval)
router.post("/", createPlaybookRunController);

// Get all accessible playbook runs
router.get("/", getPlaybookRunsController);

// Get a specific playbook run
router.get("/:id", getPlaybookRunByIdController);

// Approve or reject a playbook request (admin/operator, never own request)
router.patch("/:id/decision", decidePlaybookRunController);

// Cancel a request (requester while pending; admin/operator with a reason later)
router.post("/:id/cancel", cancelPlaybookRunController);

// Manual completion of a running run (admin/operator, reason required).
// Starting runs and normal completion are n8n machine endpoints (/api/machine).
router.post("/:id/complete", completePlaybookRunController);

export default router;
