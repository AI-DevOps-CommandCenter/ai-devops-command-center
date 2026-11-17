import express from "express";

import { loadServerConfig, type ServerConfig } from "./config/env.js";
import { authenticateToken } from "./middleware/auth.js";

import {
  securityHeaders,
  restrictedCors,
  apiRateLimiter
} from "./middleware/security.js";

import {
  notFoundHandler,
  errorHandler
} from "./middleware/error-handlers.js";

import incidentRoutes from "./routes/incident.routes.js";
import dashboardRoutes from "./routes/dashboard.routes.js";
import investigationRoutes from "./routes/investigation.routes.js";
import { createApprovalRouter } from "./routes/approval.routes.js";
import auditRoutes from "./routes/audit.routes.js";
import { createPlaybookRunRouter } from "./routes/playbook-run.routes.js";
import postmortemRoutes from "./routes/postmortem.routes.js";
import adminRoutes from "./routes/admin.routes.js";
import adminPlaybookRoutes from "./routes/admin-playbook.routes.js";
import adminIntegrationRoutes from "./routes/admin-integration.routes.js";
import remediationExecutionRoutes from "./routes/remediation-execution.routes.js";

import {
  createMachineRouter,
  type MachineDeps
} from "./routes/machine.routes.js";

import { loadSupabaseEnv } from "./config/env.js";

import {
  loadMachineEnv,
  loadRemediationWebhookEnv,
  createAutomationClientProvider
} from "./config/machine.js";
import { createGitHubRouter } from "./routes/github.routes.js";
import { loadGitHubConfig } from "./integrations/github/github.config.js";
import { GitHubService } from "./integrations/github/github.service.js";

import {
  createRemediationWebhookDispatcher,
  type RemediationWebhookDispatcher
} from "./services/remediation-webhook.service.js";

import notificationRoutes from "./routes/notification.routes.js";
import deviceTokenRoutes from "./routes/device-token.routes.js";
import { createMetricsRouter } from "./routes/metrics.routes.js";
import { createLogsRouter } from "./routes/logs.routes.js";
import { createLokiClient, type LokiClient } from "./services/logs.service.js";
import {
  createPrometheusClient,
  type PrometheusClient
} from "./services/metrics.service.js";

export interface AppOptions {
  // Machine endpoint dependencies. undefined = read from the environment;
  // null = disabled (the endpoints answer 503).
  machine?: MachineDeps | null;

  // Outgoing remediation webhook dispatcher.
  // undefined = read from the environment;
  // null = disabled.
  remediationDispatcher?: RemediationWebhookDispatcher | null;
  // Prometheus client for /api/metrics. undefined = PROMETHEUS_URL from the
  // environment; null = disabled (the endpoints answer 503).
  prometheus?: PrometheusClient | null;
  // Loki client for /api/logs. undefined = LOKI_URL from the environment;
  // null = disabled (the endpoints answer 503).
  loki?: LokiClient | null;
  // Read-only GitHub integration. undefined = read from the environment;
  // null = disabled (the endpoints answer 503).
  github?: GitHubService | null;
}

function prometheusFromEnv(): PrometheusClient | null {
  const url = process.env.PROMETHEUS_URL?.trim();
  if (!url) return null;
  if (!/^https?:\/\//.test(url)) throw new Error("PROMETHEUS_URL must be an http(s) URL.");
  return createPrometheusClient(url);
}

function lokiFromEnv(): LokiClient | null {
  const url = process.env.LOKI_URL?.trim();
  if (!url) return null;
  if (!/^https?:\/\//.test(url)) throw new Error("LOKI_URL must be an http(s) URL.");
  return createLokiClient(url);
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

// Creates the outgoing remediation webhook dispatcher when configured.
function remediationDispatcherFromEnv():
  | RemediationWebhookDispatcher
  | undefined {
  const webhookEnv = loadRemediationWebhookEnv();

  if (!webhookEnv) return undefined;

  return createRemediationWebhookDispatcher({
    url: webhookEnv.url,
    signingSecret: webhookEnv.signingSecret
  });
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

  // Resolve the outgoing webhook dispatcher once and share it between
  // approval decisions made through either API endpoint.
  const remediationDispatcher =
    options.remediationDispatcher === undefined
      ? remediationDispatcherFromEnv()
      : options.remediationDispatcher ?? undefined;

  // Body parsing
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // Incident management routes
  app.use("/api/incidents", incidentRoutes);
  app.use("/api/dashboard", dashboardRoutes);
  app.use("/api/investigations", investigationRoutes);

  app.use(
    "/api/approvals",
    createApprovalRouter(remediationDispatcher)
  );

  app.use("/api/audit-logs", auditRoutes);

  app.use(
    "/api/playbook-runs",
    createPlaybookRunRouter(remediationDispatcher)
  );

  app.use("/api/postmortems", postmortemRoutes);
  app.use("/api/admin", adminRoutes);
  app.use("/api/admin/playbooks", adminPlaybookRoutes);
  app.use("/api/admin/integrations", adminIntegrationRoutes);
  app.use("/api/remediation-executions", remediationExecutionRoutes);
  app.use("/api/notifications", notificationRoutes);
  app.use("/api/device-tokens", deviceTokenRoutes);
  app.use(
    "/api/metrics",
    createMetricsRouter(
      options.prometheus === undefined ? prometheusFromEnv() : options.prometheus
    )
  );
  app.use(
    "/api/logs",
    createLogsRouter(options.loki === undefined ? lokiFromEnv() : options.loki)
  );
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
  // Also returns the caller's application role and name from public.profiles
  // (read through the caller's own client, so RLS applies). Missing profile
  // data is simply left out.
  app.get("/api/me", authenticateToken, async (req, res) => {
    const user: Record<string, unknown> = {
      id: req.user?.id,
      email: req.user?.email
    };

    try {
      const result = await req.userSupabase
        ?.from("profiles")
        .select("role, full_name")
        .eq("id", req.user?.id ?? "")
        .maybeSingle();
      const profile = result?.data as { role?: unknown; full_name?: unknown } | null | undefined;
      if (typeof profile?.role === "string") user.role = profile.role;
      if (typeof profile?.full_name === "string" && profile.full_name.trim()) {
        user.full_name = profile.full_name.trim();
      }
    } catch {
      // Profile lookup is best-effort; authentication already succeeded.
    }

    res.json({
      success: true,
      message: "Authentication successful!",
      user
    });
  });

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}