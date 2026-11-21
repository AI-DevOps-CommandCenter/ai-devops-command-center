import { Router } from "express";

import { authenticateToken } from "../middleware/auth.js";

import {
  getNotificationsController,
  getNotificationPreferencesController,
  markNotificationReadController,
  updateNotificationPreferencesController
} from "../controllers/notification.controller.js";

const router = Router();

// All notification endpoints require authentication.
router.use(authenticateToken);

// GET /api/notifications
router.get("/", getNotificationsController);

// GET/PUT /api/notifications/preferences (S27), before the /:id routes
router.get("/preferences", getNotificationPreferencesController);
router.put("/preferences", updateNotificationPreferencesController);

// PATCH /api/notifications/:id/read
router.patch("/:id/read", markNotificationReadController);

export default router;