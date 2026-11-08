import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  createApprovalController,
  getApprovalsController,
  getApprovalByIdController,
  decideApprovalController,
  cancelApprovalController
} from "../controllers/approval.controller.js";

const router = Router();

router.use(authenticateToken);

router.post("/", createApprovalController);
router.get("/", getApprovalsController);
router.get("/:id", getApprovalByIdController);
router.patch("/:id/decision", decideApprovalController);
router.post("/:id/cancel", cancelApprovalController);

export default router;
