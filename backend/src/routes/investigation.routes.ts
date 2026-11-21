import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  createInvestigationController,
  getInvestigationsByIncidentController,
  getInvestigationByIdController,
  updateInvestigationController
} from "../controllers/investigation.controller.js";

const router = Router();

router.use(authenticateToken);

router.post("/", createInvestigationController);
router.get("/", getInvestigationsByIncidentController);
router.get("/:id", getInvestigationByIdController);
router.patch("/:id", updateInvestigationController);

export default router;