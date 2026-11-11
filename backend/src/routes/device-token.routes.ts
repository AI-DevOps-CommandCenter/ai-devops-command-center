import { Router } from "express";

import { authenticateToken } from "../middleware/auth.js";

import {
  registerDeviceTokenController,
  unregisterDeviceTokenController
} from "../controllers/notification.controller.js";

const router = Router();

// All device-token endpoints require authentication.
router.use(authenticateToken);

// POST /api/device-tokens
router.post("/", registerDeviceTokenController);

// DELETE /api/device-tokens
router.delete("/", unregisterDeviceTokenController);

export default router;