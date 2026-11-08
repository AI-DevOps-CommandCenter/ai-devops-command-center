import { z } from "zod";

// Message kept identical to the original startup check so existing
// operational behaviour (and any scripts relying on it) is unchanged.
export const MISSING_SUPABASE_ENV_MESSAGE =
  "Supabase environment variables are missing!";

export const PRIVILEGED_KEY_MESSAGE =
  "SUPABASE_PUBLISHABLE_KEY must be a publishable (client) key. " +
  "Privileged/secret keys are not allowed in the backend runtime (decision D-001).";

/**
 * Returns true when the key is a Supabase privileged key:
 * - new-style secret keys ("sb_secret_..."), or
 * - legacy JWT-style keys whose payload role is not "anon".
 *
 * The key is decoded locally only; it is never logged or sent anywhere.
 */
export function isPrivilegedSupabaseKey(key: string): boolean {
  const trimmed = key.trim();

  if (trimmed.startsWith("sb_secret_")) {
    return true;
  }

  const parts = trimmed.split(".");

  if (parts.length === 3) {
    try {
      const payload = JSON.parse(
        Buffer.from(parts[1], "base64url").toString("utf8")
      ) as { role?: unknown };

      return typeof payload.role === "string" && payload.role !== "anon";
    } catch {
      // Not a decodable JWT: treat as an opaque publishable key.
      return false;
    }
  }

  return false;
}

const supabaseEnvSchema = z.object({
  SUPABASE_URL: z.url({ protocol: /^https?$/ }),
  SUPABASE_PUBLISHABLE_KEY: z
    .string()
    .trim()
    .min(1)
    .refine((key) => !isPrivilegedSupabaseKey(key), {
      message: PRIVILEGED_KEY_MESSAGE
    })
});

export type SupabaseEnv = z.infer<typeof supabaseEnvSchema>;

export function loadSupabaseEnv(
  env: NodeJS.ProcessEnv = process.env
): SupabaseEnv {
  if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) {
    throw new Error(MISSING_SUPABASE_ENV_MESSAGE);
  }

  const result = supabaseEnvSchema.safeParse(env);

  if (!result.success) {
    // Report which variable is wrong, never its value.
    const problems = result.error.issues
      .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
      .join("; ");

    throw new Error(`Invalid Supabase configuration: ${problems}`);
  }

  return result.data;
}

// Treat empty or whitespace-only values (e.g. "PORT=" in a .env file) as
// unset, so defaults apply. This matches the original `process.env.PORT || 3000`.
function optionalEnv<T extends z.ZodType>(schema: T) {
  return z.preprocess(
    (value) =>
      typeof value === "string" && value.trim() === "" ? undefined : value,
    schema
  );
}

const serverEnvSchema = z.object({
  PORT: optionalEnv(z.coerce.number().int().min(1).max(65535).default(3000)),
  // Comma-separated list of allowed browser origins. Empty = no
  // cross-origin browser access (native mobile clients are unaffected).
  CORS_ORIGINS: optionalEnv(z.string().default("")),
  RATE_LIMIT_WINDOW_MS: optionalEnv(
    z.coerce.number().int().positive().default(15 * 60 * 1000)
  ),
  RATE_LIMIT_MAX: optionalEnv(z.coerce.number().int().positive().default(300)),
  // Number of trusted reverse-proxy hops (e.g. 1 behind a single proxy) so
  // rate limiting sees the real client IP. 0 = trust no proxy. Booleans are
  // not accepted: "true" would trust any X-Forwarded-For value and let
  // clients bypass the rate limit.
  TRUST_PROXY: optionalEnv(z.coerce.number().int().min(0).max(10).default(0))
});

export interface ServerConfig {
  port: number;
  corsOrigins: string[];
  rateLimitWindowMs: number;
  rateLimitMax: number;
  trustProxy: number;
}

export function loadServerConfig(
  env: NodeJS.ProcessEnv = process.env
): ServerConfig {
  const result = serverEnvSchema.safeParse(env);

  if (!result.success) {
    const problems = result.error.issues
      .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
      .join("; ");

    throw new Error(`Invalid server configuration: ${problems}`);
  }

  const parsed = result.data;

  return {
    port: parsed.PORT,
    corsOrigins: parsed.CORS_ORIGINS.split(",")
      .map((origin) => origin.trim())
      .filter((origin) => origin.length > 0),
    rateLimitWindowMs: parsed.RATE_LIMIT_WINDOW_MS,
    rateLimitMax: parsed.RATE_LIMIT_MAX,
    trustProxy: parsed.TRUST_PROXY
  };
}
