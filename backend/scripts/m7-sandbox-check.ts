// Manual sandbox check for the M7 integrations against REAL services.
// Not part of `npm test`. Nothing runs unless you pass --confirm.
//
//   cd backend
//   npx tsx scripts/m7-sandbox-check.ts --confirm            # GitHub reads only
//   npx tsx scripts/m7-sandbox-check.ts --confirm --send     # + one test message per configured channel
//
// Uses the normal backend .env (GITHUB_*, SLACK_WEBHOOK_URL, DISCORD_WEBHOOK_URL,
// SMTP_*, EMAIL_FROM). For e-mail also set M7_SANDBOX_EMAIL_TO to a mailbox
// you own. Use sandbox channels/webhooks and a test repository only.
// The output never contains tokens, webhook URLs or passwords.

import "../src/config/load-env.js";

import { loadGitHubConfig } from "../src/integrations/github/github.config.js";
import { GitHubService } from "../src/integrations/github/github.service.js";
import { createNotificationSenders, type ClaimedDelivery } from "../src/integrations/notifications/index.js";

const args = new Set(process.argv.slice(2));

async function checkGitHub() {
  const config = loadGitHubConfig();
  if (!config) return console.log("GitHub: not configured (skipped)");

  const service = new GitHubService(config);
  const [ref] = config.repositories;
  try {
    const repo = await service.getRepository(ref);
    const commits = await service.listCommits(ref, { limit: 3 });
    const pulls = await service.listPullRequests(ref, { state: "all", limit: 3 });
    const runs = await service.listWorkflowRuns(ref, { limit: 3 });
    console.log(
      `GitHub: OK ${repo.full_name} (default ${repo.default_branch}); ` +
        `${commits.length} commits, ${pulls.length} PRs, ${runs.length} workflow runs read`
    );
  } catch (error) {
    console.log(`GitHub: FAILED ${(error as Error).name}: ${(error as Error).message}`);
  }
}

async function checkSenders() {
  const senders = createNotificationSenders();
  if (senders.size === 0) return console.log("Notifications: no channel configured (skipped)");

  const now = new Date().toISOString();
  for (const [channel, sender] of senders) {
    const recipient = process.env.M7_SANDBOX_EMAIL_TO?.trim() ?? "";
    if (channel === "email" && !recipient) {
      console.log("email: skipped (set M7_SANDBOX_EMAIL_TO)");
      continue;
    }
    const delivery: ClaimedDelivery = {
      delivery_id: `sandbox-${channel}`,
      channel,
      attempt_count: 1,
      notification_id: "sandbox",
      user_id: null,
      incident_id: null,
      title: "M7 sandbox test",
      message: `Test message from the M7 sandbox check at ${now}. No action needed.`,
      recipient_email: channel === "email" ? recipient : null,
      device_tokens: null
    };
    const result = await sender.send(delivery);
    console.log(
      result.status === "sent"
        ? `${channel}: SENT (provider id: ${result.providerMessageId ?? "none"})`
        : `${channel}: FAILED (${result.retryable ? "retryable" : "permanent"}) ${result.errorMessage}`
    );
  }
}

if (!args.has("--confirm")) {
  console.log("This script contacts real services. Re-run with --confirm (and --send to send test messages).");
  process.exit(1);
}

console.log(`M7 sandbox check, ${new Date().toISOString()}`);
await checkGitHub();
if (args.has("--send")) await checkSenders();
else console.log("Notifications: not sent (pass --send)");
