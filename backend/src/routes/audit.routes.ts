import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  getAuditLogsController
} from "../controllers/audit.controller.js";

const router = Router();

router.use(authenticateToken);

router.get("/", getAuditLogsController);

export default router;