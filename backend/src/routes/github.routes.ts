import { Router } from "express";
import { z } from "zod";

import { authenticateToken } from "../middleware/auth.js";
import { validate } from "../middleware/validate.js";
import { createGitHubController } from "../controllers/github.controller.js";
import { GITHUB_NAME_PATTERN } from "../integrations/github/github.config.js";
import {
  PULL_REQUEST_STATES,
  WORKFLOW_RUN_STATUSES,
  type GitHubService
} from "../integrations/github/github.service.js";

// Read-only GitHub endpoints for the mobile Repositories screens (owner: M7).
// Every endpoint needs a signed-in user. Only repositories on the
// GITHUB_REPOSITORIES allow-list are served.

const repoParams = z.object({
  owner: z.string().regex(GITHUB_NAME_PATTERN, "Invalid repository owner."),
  repo: z.string().regex(GITHUB_NAME_PATTERN, "Invalid repository name.")
});

// Branch names: the common safe subset of git ref names.
const branchSchema = z
  .string()
  .trim()
  .regex(/^(?!.*\.\.)(?!\/)[A-Za-z0-9._/-]{1,255}$/, "Invalid branch name.");

const limitSchema = z.coerce.number().int().min(1).max(100).default(20);
const positiveId = z.coerce.number().int().positive().max(Number.MAX_SAFE_INTEGER);

const commitsQuery = z.object({ branch: branchSchema.optional(), limit: limitSchema });
const pullsQuery = z.object({ state: z.enum(PULL_REQUEST_STATES).default("open"), limit: limitSchema });
const runsQuery = z.object({
  branch: branchSchema.optional(),
  status: z.enum(WORKFLOW_RUN_STATUSES).optional(),
  limit: limitSchema
});

export function createGitHubRouter(service: GitHubService | null) {
  const router = Router();

  router.use(authenticateToken);

  if (!service) {
    router.use((_req, res) => {
      res.status(503).json({ success: false, message: "GitHub integration is not configured." });
    });
    return router;
  }

  const controller = createGitHubController(service);
  const base = "/repositories/:owner/:repo";

  router.get("/repositories", controller.listRepositories);
  router.get(base, validate({ params: repoParams }), controller.getRepository);
  router.get(`${base}/commits`, validate({ params: repoParams, query: commitsQuery }), controller.listCommits);
  router.get(`${base}/pulls`, validate({ params: repoParams, query: pullsQuery }), controller.listPullRequests);
  router.get(
    `${base}/pulls/:number`,
    validate({ params: repoParams.extend({ number: positiveId }) }),
    controller.getPullRequest
  );
  router.get(`${base}/workflow-runs`, validate({ params: repoParams, query: runsQuery }), controller.listWorkflowRuns);
  router.get(
    `${base}/workflow-runs/:runId/jobs`,
    validate({ params: repoParams.extend({ runId: positiveId }) }),
    controller.listWorkflowRunJobs
  );

  return router;
}
