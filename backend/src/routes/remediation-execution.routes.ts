import { Router } from "express";

import { authenticateToken } from "../middleware/auth.js";

import {
  createRemediationExecutionController,
  getRemediationExecutionsController,
  getRemediationExecutionByIdController,
  updateRemediationExecutionController
} from "../controllers/remediation-execution.controller.js";

const router = Router();

router.use(authenticateToken);

router.post("/", createRemediationExecutionController);
router.get("/", getRemediationExecutionsController);
router.get("/:id", getRemediationExecutionByIdController);
router.patch("/:id", updateRemediationExecutionController);

export default router;
