// Password reset through Supabase Auth (GoTrue), with the publishable key only.
//
// 1. POST /auth/v1/recover?redirect_to=<app>  Supabase emails a one-time link.
//    The link signs the user in and lands on <app>#access_token=…&type=recovery.
// 2. PUT  /auth/v1/user  with that access token sets the new password.
//
// The interface lets the routes be tested without Supabase.

export interface PasswordResetClient {
  // Resolves when Supabase accepted the request, including for unknown emails
  // (Supabase does not reveal whether an account exists).
  sendResetEmail(email: string, redirectTo: string): Promise<void>;
  // accessToken is the recovery session token from the email link.
  updatePassword(accessToken: string, password: string): Promise<void>;
}

export class PasswordResetRateLimitedError extends Error {}
export class PasswordResetUnavailableError extends Error {}
export class InvalidRecoveryTokenError extends Error {}
export class PasswordRejectedError extends Error {}

const TIMEOUT_MS = 10_000;

type Fetch = typeof fetch;

async function readError(response: Response): Promise<{ code: string; message: string }> {
  try {
    const body = (await response.json()) as Record<string, unknown>;
    return {
      code: String(body.error_code ?? body.code ?? body.error ?? ""),
      message: String(body.msg ?? body.message ?? body.error_description ?? "")
    };
  } catch {
    return { code: "", message: "" };
  }
}

export function createSupabasePasswordResetClient(
  supabaseUrl: string,
  publishableKey: string,
  fetchImpl: Fetch = fetch
): PasswordResetClient {
  const base = supabaseUrl.replace(/\/+$/, "") + "/auth/v1";

  async function call(path: string, init: RequestInit): Promise<Response> {
    try {
      return await fetchImpl(base + path, { ...init, signal: AbortSignal.timeout(TIMEOUT_MS) });
    } catch {
      throw new PasswordResetUnavailableError("Supabase Auth is not reachable.");
    }
  }

  return {
    async sendResetEmail(email, redirectTo) {
      const response = await call(`/recover?redirect_to=${encodeURIComponent(redirectTo)}`, {
        method: "POST",
        headers: { apikey: publishableKey, "Content-Type": "application/json" },
        body: JSON.stringify({ email })
      });
      if (response.ok) return;
      const error = await readError(response);
      if (response.status === 429 || error.code.includes("rate_limit")) {
        throw new PasswordResetRateLimitedError("Too many reset emails were requested.");
      }
      // Unknown users and similar 4xx answers are treated as "sent" by the
      // route, so the response never reveals whether an account exists.
      if (response.status >= 400 && response.status < 500) return;
      throw new PasswordResetUnavailableError(`Supabase Auth answered HTTP ${response.status}.`);
    },

    async updatePassword(accessToken, password) {
      const response = await call("/user", {
        method: "PUT",
        headers: {
          apikey: publishableKey,
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ password })
      });
      if (response.ok) return;
      const error = await readError(response);
      if (response.status === 401 || response.status === 403) {
        throw new InvalidRecoveryTokenError("The reset link is invalid or has expired.");
      }
      if (response.status === 422 || response.status === 400) {
        if (error.code === "same_password") {
          throw new PasswordRejectedError("The new password must be different from the old one.");
        }
        throw new PasswordRejectedError(error.message || "The password was rejected (too weak).");
      }
      if (response.status === 429) {
        throw new PasswordResetRateLimitedError("Too many attempts.");
      }
      throw new PasswordResetUnavailableError(`Supabase Auth answered HTTP ${response.status}.`);
    }
  };
}

// Where the email link sends the user back to: the web app (Flutter) by default.
// Must also be listed in Supabase -> Authentication -> URL Configuration.
export const DEFAULT_PASSWORD_RESET_REDIRECT_URL = "http://127.0.0.1:8080/";

export function passwordResetRedirectFromEnv(env: NodeJS.ProcessEnv = process.env): string {
  const value = env.PASSWORD_RESET_REDIRECT_URL?.trim() || DEFAULT_PASSWORD_RESET_REDIRECT_URL;
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("PASSWORD_RESET_REDIRECT_URL must be an absolute http(s) URL.");
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error("PASSWORD_RESET_REDIRECT_URL must be an absolute http(s) URL.");
  }
  return url.toString();
}
