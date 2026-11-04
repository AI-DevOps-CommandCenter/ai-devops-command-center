
import express from "express";
import cors from "cors";

import { authenticateToken } from "./middleware/auth.js";
import incidentRoutes from "./routes/incident.routes.js";
import dashboardRoutes from "./routes/dashboard.routes.js";
import investigationRoutes from "./routes/investigation.routes.js";
import approvalRoutes from "./routes/approval.routes.js";
import auditRoutes from "./routes/audit.routes.js";
import playbookRunRoutes from "./routes/playbook-run.routes.js";
import postmortemRoutes from "./routes/postmortem.routes.js";
import adminRoutes from "./routes/admin.routes.js";
import adminPlaybookRoutes from "./routes/admin-playbook.routes.js";

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
app.use("/api/playbook-runs", playbookRunRoutes);
app.use("/api/postmortems", postmortemRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/admin/playbooks", adminPlaybookRoutes);

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
