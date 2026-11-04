
import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  createPostmortemController,
  getPostmortemsController,
  getPostmortemByIdController,
  updatePostmortemController
} from "../controllers/postmortem.controller.js";

const router = Router();

// All postmortem endpoints require authentication
router.use(authenticateToken);

// Create a postmortem
router.post("/", createPostmortemController);

// Get all accessible postmortems
router.get("/", getPostmortemsController);

// Get a specific postmortem
router.get("/:id", getPostmortemByIdController);

// Update a postmortem
router.patch("/:id", updatePostmortemController);

export default router;
