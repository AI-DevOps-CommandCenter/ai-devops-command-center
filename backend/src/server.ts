
import express from "express";
import cors from "cors";

import { authenticateToken } from "./middleware/auth.js";
import incidentRoutes from "./routes/incident.routes.js";
import dashboardRoutes from "./routes/dashboard.routes.js";
import investigationRoutes from "./routes/investigation.routes.js";
import approvalRoutes from "./routes/approval.routes.js";
import auditRoutes from "./routes/audit.routes.js";

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Incident management routes
app.use("/api/incidents", incidentRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/investigations", investigationRoutes);
app.use("/api/approvals", approvalRoutes);
app.use("/api/audit-logs", auditRoutes);

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
