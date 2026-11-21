import { createClient } from "@supabase/supabase-js";

import { MIN_SECRET_LENGTH } from "../middleware/machine-auth.js";
import type { UserSupabaseClient } from "./supabase.js";

// Configuration for the n8n machine endpoints (decision A5).
//
// n8n never talks to the database. It calls signed backend endpoints, and
// the backend performs the database call as the dedicated automation
// identity: a Supabase Auth user whose profile role is `automation`
// (assignable only by the database owner, migration 000400). The backend
// signs in as that user with the publishable key, so no privileged key is
// used (D-001). The database functions themselves reject any other role.
//
// All three variables are required to enable the endpoints; without them
// the endpoints answer 503. Provisioning and rotation of the automation
// identity and the signing secret is open decision A5-Q2.

export interface MachineEnv {
  signingSecret: string;
  automationEmail: string;
  automationPassword: string;
}
// Configuration shared by background workers that use the
// dedicated automation identity, independently of n8n machine endpoints.
export interface AutomationEnv {
  automationEmail: string;
  automationPassword: string;
}

export function loadAutomationEnv(
  env: NodeJS.ProcessEnv = process.env
): AutomationEnv | null {
  const automationEmail = env.AUTOMATION_EMAIL?.trim() ?? "";
  const automationPassword = env.AUTOMATION_PASSWORD ?? "";

  if (!automationEmail && !automationPassword) {
    return null;
  }

  const missing = [
    !automationEmail && "AUTOMATION_EMAIL",
    !automationPassword && "AUTOMATION_PASSWORD"
  ].filter(Boolean);

  if (missing.length > 0) {
    throw new Error(
      `Invalid automation configuration: missing ${missing.join(", ")}`
    );
  }

  return { automationEmail, automationPassword };
}

export function loadMachineEnv(
  env: NodeJS.ProcessEnv = process.env
): MachineEnv | null {
  const signingSecret = env.MACHINE_SIGNING_SECRET?.trim() ?? "";
  const automationEmail = env.AUTOMATION_EMAIL?.trim() ?? "";
  const automationPassword = env.AUTOMATION_PASSWORD ?? "";

  if (!signingSecret && !automationEmail && !automationPassword) {
    return null;
  }

  // Partly configured: report which variable is missing, never a value.
  const missing = [
    !signingSecret && "MACHINE_SIGNING_SECRET",
    !automationEmail && "AUTOMATION_EMAIL",
    !automationPassword && "AUTOMATION_PASSWORD"
  ].filter(Boolean);

  if (missing.length > 0) {
    throw new Error(
      `Invalid machine endpoint configuration: missing ${missing.join(", ")}`
    );
  }

  if (signingSecret.length < MIN_SECRET_LENGTH) {
    throw new Error(
      `Invalid machine endpoint configuration: MACHINE_SIGNING_SECRET must be at least ${MIN_SECRET_LENGTH} characters`
    );
  }

  return { signingSecret, automationEmail, automationPassword };
}

// Same client type as the per-request user client: a publishable-key client
// that carries a user JWT (here, the automation identity's).
export type AutomationClient = UserSupabaseClient;

export interface AutomationClientProvider {
  get(): Promise<AutomationClient>;
  invalidate(): void;
}

// Signs in as the automation identity once and reuses the session (the
// Supabase client refreshes the token in memory). invalidate() forces a new
// sign-in, e.g. after the session was revoked.
export function createAutomationClientProvider(options: {
  supabaseUrl: string;
  publishableKey: string;
  email: string;
  password: string;
}): AutomationClientProvider {
  let pending: Promise<AutomationClient> | null = null;

  async function signIn(): Promise<AutomationClient> {
    const client = createClient(options.supabaseUrl, options.publishableKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: true,
        detectSessionInUrl: false
      }
    });

    const { error } = await client.auth.signInWithPassword({
      email: options.email,
      password: options.password
    });

    if (error) {
      throw new Error("Automation identity sign-in failed.");
    }

    return client as unknown as AutomationClient;
  }

  return {
    get() {
      if (pending) return pending;

      const attempt = signIn();
      pending = attempt;
      // A failed sign-in is not cached: the next request tries again.
      attempt.catch(() => {
        if (pending === attempt) pending = null;
      });

      return attempt;
    },
    invalidate() {
      pending = null;
    }
  };
}

export interface RemediationWebhookEnv {
  url: string;
  signingSecret: string;
}

export function loadRemediationWebhookEnv():
  | RemediationWebhookEnv
  | null {
  const url = process.env.N8N_REMEDIATION_WEBHOOK_URL?.trim();

  // Outgoing remediation dispatch is disabled when no URL is configured.
  if (!url) return null;

  const signingSecret = process.env.MACHINE_SIGNING_SECRET?.trim();

  if (!signingSecret || signingSecret.length < MIN_SECRET_LENGTH) {
    throw new Error(
      "N8N_REMEDIATION_WEBHOOK_URL requires a valid MACHINE_SIGNING_SECRET."
    );
  }

  let parsedUrl: URL;

  try {
    parsedUrl = new URL(url);
  } catch {
    throw new Error("N8N_REMEDIATION_WEBHOOK_URL must be a valid URL.");
  }

  if (
    parsedUrl.protocol !== "https:" &&
    parsedUrl.hostname !== "localhost" &&
    parsedUrl.hostname !== "127.0.0.1"
  ) {
    throw new Error(
      "N8N_REMEDIATION_WEBHOOK_URL must use HTTPS outside localhost."
    );
  }

  if (parsedUrl.pathname !== "/webhook/remediation") {
    throw new Error(
      "N8N_REMEDIATION_WEBHOOK_URL must point to /webhook/remediation."
    );
  }

  return { url, signingSecret };
}