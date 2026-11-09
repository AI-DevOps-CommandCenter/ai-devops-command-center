import express from "express";

import { loadServerConfig, type ServerConfig } from "./config/env.js";
import { authenticateToken } from "./middleware/auth.js";
import {
  securityHeaders,
  restrictedCors,
  apiRateLimiter
} from "./middleware/security.js";
import { notFoundHandler, errorHandler } from "./middleware/error-handlers.js";
import incidentRoutes from "./routes/incident.routes.js";
import dashboardRoutes from "./routes/dashboard.routes.js";
import investigationRoutes from "./routes/investigation.routes.js";
import approvalRoutes from "./routes/approval.routes.js";
import auditRoutes from "./routes/audit.routes.js";
import playbookRunRoutes from "./routes/playbook-run.routes.js";
import postmortemRoutes from "./routes/postmortem.routes.js";
import adminRoutes from "./routes/admin.routes.js";
import adminPlaybookRoutes from "./routes/admin-playbook.routes.js";
import adminIntegrationRoutes from "./routes/admin-integration.routes.js";
import remediationExecutionRoutes from "./routes/remediation-execution.routes.js";
import { createMachineRouter, type MachineDeps } from "./routes/machine.routes.js";
import { loadSupabaseEnv } from "./config/env.js";
import {
  loadMachineEnv,
  createAutomationClientProvider
} from "./config/machine.js";
import { createGitHubRouter } from "./routes/github.routes.js";
import { loadGitHubConfig } from "./integrations/github/github.config.js";
import { GitHubService } from "./integrations/github/github.service.js";

export interface AppOptions {
  // Machine endpoint dependencies. undefined = read from the environment;
  // null = disabled (the endpoints answer 503).
  machine?: MachineDeps | null;
  // Read-only GitHub integration. undefined = read from the environment;
  // null = disabled (the endpoints answer 503).
  github?: GitHubService | null;
}

// GitHub endpoints are enabled only when GITHUB_TOKEN and
// GITHUB_REPOSITORIES are set.
function gitHubServiceFromEnv(): GitHubService | null {
  const config = loadGitHubConfig();
  return config ? new GitHubService(config) : null;
}

// n8n machine endpoints are enabled only when MACHINE_SIGNING_SECRET,
// AUTOMATION_EMAIL and AUTOMATION_PASSWORD are all set (decision A5).
function machineDepsFromEnv(): MachineDeps | null {
  const machineEnv = loadMachineEnv();

  if (!machineEnv) return null;

  const supabaseEnv = loadSupabaseEnv();

  return {
    signingSecret: machineEnv.signingSecret,
    automation: createAutomationClientProvider({
      supabaseUrl: supabaseEnv.SUPABASE_URL,
      publishableKey: supabaseEnv.SUPABASE_PUBLISHABLE_KEY,
      email: machineEnv.automationEmail,
      password: machineEnv.automationPassword
    })
  };
}

// Builds the Express application without starting a listener, so it can be
// tested with Supertest. Route paths and responses are unchanged.
export function createApp(
  config: ServerConfig = loadServerConfig(),
  options: AppOptions = {}
) {
  const app = express();

  app.disable("x-powered-by");
  app.set("trust proxy", config.trustProxy);

  // Security middleware
  app.use(securityHeaders());
  app.use(restrictedCors(config.corsOrigins));
  app.use("/api", apiRateLimiter(config));

  // n8n machine endpoints: mounted before the global JSON parser because the
  // request signature is verified against the raw body.
  app.use(
    "/api/machine",
    createMachineRouter(
      options.machine === undefined ? machineDepsFromEnv() : options.machine
    )
  );

  // Body parsing
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
  app.use("/api/admin/integrations", adminIntegrationRoutes);
  app.use("/api/remediation-executions", remediationExecutionRoutes);
  app.use(
    "/api/github",
    createGitHubRouter(
      options.github === undefined ? gitHubServiceFromEnv() : options.github
    )
  );

  app.get("/", (_req, res) => {
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

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
