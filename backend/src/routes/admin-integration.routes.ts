import { Router } from "express";
import {
  getIntegrationsController,
  createIntegrationController,
  updateIntegrationController,
  deleteIntegrationController
} from "../controllers/admin-integration.controller.js";
import { authenticateToken } from "../middleware/auth.js";

const router = Router();

router.use(authenticateToken);

router.get("/", getIntegrationsController);
router.post("/", createIntegrationController);
router.patch("/:id", updateIntegrationController);
router.delete("/:id", deleteIntegrationController);

export default router;
