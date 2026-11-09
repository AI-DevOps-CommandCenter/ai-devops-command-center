import type { Request, Response } from "express";

import {
  isGitHubError,
  type GitHubService
} from "../integrations/github/github.service.js";
import type { GitHubRepoRef } from "../integrations/github/github.config.js";

// Controllers for the read-only GitHub endpoints. Inputs were validated by
// the route's Zod schemas (res.locals.validated).

interface RepoParams {
  owner: string;
  repo: string;
}

function validated<T>(res: Response, location: "params" | "query"): T {
  return (res.locals.validated?.[location] ?? {}) as T;
}

// Maps service errors to HTTP. GitHub's own 401/403 is reported as 502:
// it means the backend's token is wrong, not the caller's.
export function sendGitHubError(res: Response, error: unknown, action: string) {
  if (isGitHubError(error)) {
    switch (error.kind) {
      case "not_found":
        return res.status(404).json({ success: false, message: "GitHub resource not found." });
      case "rate_limited":
        if (error.retryAfterMs !== undefined) {
          res.set("Retry-After", String(Math.max(1, Math.ceil(error.retryAfterMs / 1000))));
        }
        return res.status(503).json({
          success: false,
          message: "GitHub rate limit reached. Please try again later."
        });
      case "auth":
        return res.status(502).json({ success: false, message: "GitHub integration is misconfigured." });
      case "unavailable":
      case "invalid_response":
        return res.status(502).json({ success: false, message: "GitHub is currently unavailable." });
    }
  }

  console.error(`GitHub ${action} error:`, error);
  return res.status(500).json({ success: false, message: "Internal server error." });
}

function resolveOr404(service: GitHubService, req: Request, res: Response): GitHubRepoRef | null {
  const { owner, repo } = validated<RepoParams>(res, "params");
  const ref = service.resolveRepository(owner, repo);

  // Not on the allow-list: answer like a missing repository, without
  // contacting GitHub, so the backend token can't read other repositories.
  if (!ref) {
    res.status(404).json({ success: false, message: "Repository not found." });
  }
  return ref;
}

export function createGitHubController(service: GitHubService) {
  return {
    async listRepositories(_req: Request, res: Response) {
      try {
        const data = await service.listRepositories();
        return res.status(200).json({
          success: true,
          message: "Repositories retrieved successfully.",
          count: data.length,
          data
        });
      } catch (error) {
        return sendGitHubError(res, error, "list repositories");
      }
    },

    async getRepository(req: Request, res: Response) {
      const ref = resolveOr404(service, req, res);
      if (!ref) return;
      try {
        const data = await service.getRepository(ref);
        return res.status(200).json({ success: true, message: "Repository retrieved successfully.", data });
      } catch (error) {
        return sendGitHubError(res, error, "get repository");
      }
    },

    async listCommits(req: Request, res: Response) {
      const ref = resolveOr404(service, req, res);
      if (!ref) return;
      const { branch, limit } = validated<{ branch?: string; limit: number }>(res, "query");
      try {
        const data = await service.listCommits(ref, { branch, limit });
        return res.status(200).json({
          success: true,
          message: "Commits retrieved successfully.",
          count: data.length,
          data
        });
      } catch (error) {
        return sendGitHubError(res, error, "list commits");
      }
    },

    async listPullRequests(req: Request, res: Response) {
      const ref = resolveOr404(service, req, res);
      if (!ref) return;
      const { state, limit } = validated<{ state: "open" | "closed" | "all"; limit: number }>(res, "query");
      try {
        const data = await service.listPullRequests(ref, { state, limit });
        return res.status(200).json({
          success: true,
          message: "Pull requests retrieved successfully.",
          count: data.length,
          data
        });
      } catch (error) {
        return sendGitHubError(res, error, "list pull requests");
      }
    },

    async getPullRequest(req: Request, res: Response) {
      const ref = resolveOr404(service, req, res);
      if (!ref) return;
      const { number } = validated<{ number: number }>(res, "params");
      try {
        const data = await service.getPullRequest(ref, number);
        return res.status(200).json({ success: true, message: "Pull request retrieved successfully.", data });
      } catch (error) {
        return sendGitHubError(res, error, "get pull request");
      }
    },

    async listWorkflowRuns(req: Request, res: Response) {
      const ref = resolveOr404(service, req, res);
      if (!ref) return;
      const query = validated<{
        branch?: string;
        status?: "queued" | "in_progress" | "completed" | "success" | "failure" | "cancelled";
        limit: number;
      }>(res, "query");
      try {
        const data = await service.listWorkflowRuns(ref, query);
        return res.status(200).json({
          success: true,
          message: "Workflow runs retrieved successfully.",
          count: data.length,
          data
        });
      } catch (error) {
        return sendGitHubError(res, error, "list workflow runs");
      }
    },

    async listWorkflowRunJobs(req: Request, res: Response) {
      const ref = resolveOr404(service, req, res);
      if (!ref) return;
      const { runId } = validated<{ runId: number }>(res, "params");
      try {
        const data = await service.listWorkflowRunJobs(ref, runId);
        return res.status(200).json({
          success: true,
          message: "Workflow jobs retrieved successfully.",
          count: data.length,
          data
        });
      } catch (error) {
        return sendGitHubError(res, error, "list workflow jobs");
      }
    }
  };
}
