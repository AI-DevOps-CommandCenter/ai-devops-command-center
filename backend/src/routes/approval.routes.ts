import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  createApprovalController,
  getApprovalsController,
  getApprovalByIdController,
  decideApprovalController
} from "../controllers/approval.controller.js";

const router = Router();

router.use(authenticateToken);

router.post("/", createApprovalController);
router.get("/", getApprovalsController);
router.get("/:id", getApprovalByIdController);
router.patch("/:id/decision", decideApprovalController);

export default router;