
import express from "express";
import cors from "cors";
import dotenv from "dotenv";

import { authenticateToken } from "./middleware/auth.js";
import incidentRoutes from "./routes/incident.routes.js";

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Incident management routes
app.use("/api/incidents", incidentRoutes);

const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.json({
    message: "AI-Powered Mobile DevOps Command Center API is running!"
  });
});

// Authentication test endpoint
app.get("/api/me", authenticateToken, (req, res) => {
  res.json({
    success: true,
    message: "Authentication successful!",
    user: {
      id: req.user?.id,
      email: req.user?.email
    }
  });
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});
