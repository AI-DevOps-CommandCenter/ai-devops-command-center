import { Router } from "express";

import { authenticateToken } from "../middleware/auth.js";

import {
  getNotificationsController,
  markNotificationReadController
} from "../controllers/notification.controller.js";

const router = Router();

// All notification endpoints require authentication.
router.use(authenticateToken);

// GET /api/notifications
router.get("/", getNotificationsController);

// PATCH /api/notifications/:id/read
router.patch("/:id/read", markNotificationReadController);

export default router;