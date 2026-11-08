import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  getAllPlaybooksController,
  createPlaybookController,
  updatePlaybookController,
  deletePlaybookController
} from "../controllers/admin-playbook.controller.js";

const router = Router();

router.use(authenticateToken);

router.get("/", getAllPlaybooksController);
router.post("/", createPlaybookController);
router.patch("/:id", updatePlaybookController);
router.delete("/:id", deletePlaybookController);

export default router;