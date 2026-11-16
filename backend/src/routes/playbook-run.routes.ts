import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  createPlaybookRunController,
  getPlaybookRunsController,
  getPlaybookRunByIdController,
  createDecidePlaybookRunController,
  cancelPlaybookRunController,
  completePlaybookRunController
} from "../controllers/playbook-run.controller.js";

import type { RemediationWebhookDispatcher } from "../services/remediation-webhook.service.js";

export function createPlaybookRunRouter(
  dispatcher?: RemediationWebhookDispatcher
) {
  const router = Router();

  router.use(authenticateToken);

  router.post("/", createPlaybookRunController);
  router.get("/", getPlaybookRunsController);
  router.get("/:id", getPlaybookRunByIdController);
  router.patch(
    "/:id/decision",
    createDecidePlaybookRunController(dispatcher)
  );
  router.post("/:id/cancel", cancelPlaybookRunController);
  router.post("/:id/complete", completePlaybookRunController);

  return router;
}

export default createPlaybookRunRouter();