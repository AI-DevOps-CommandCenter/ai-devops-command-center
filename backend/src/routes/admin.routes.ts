import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  getUsersController,
  updateUserRoleController
} from "../controllers/admin.controller.js";

const router = Router();

router.use(authenticateToken);

router.get("/users", getUsersController);
router.patch("/users/:id/role", updateUserRoleController);

export default router;