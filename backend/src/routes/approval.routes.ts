import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  createApprovalController,
  getApprovalsController,
  getApprovalByIdController,
  createDecideApprovalController,
  cancelApprovalController
} from "../controllers/approval.controller.js";
import type { RemediationWebhookDispatcher } from "../services/remediation-webhook.service.js";

export function createApprovalRouter(
  dispatcher?: RemediationWebhookDispatcher
) {
  const router = Router();

  router.use(authenticateToken);

  router.post("/", createApprovalController);
  router.get("/", getApprovalsController);
  router.get("/:id", getApprovalByIdController);
  router.patch("/:id/decision", createDecideApprovalController(dispatcher));
  router.post("/:id/cancel", cancelApprovalController);

  return router;
}

export default createApprovalRouter();