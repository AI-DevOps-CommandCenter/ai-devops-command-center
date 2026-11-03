
import express from "express";
import cors from "cors";

import { authenticateToken } from "./middleware/auth.js";
import incidentRoutes from "./routes/incident.routes.js";
import dashboardRoutes from "./routes/dashboard.routes.js";
import investigationRoutes from "./routes/investigation.routes.js";

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Incident management routes
app.use("/api/incidents", incidentRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/investigations", investigationRoutes);

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
