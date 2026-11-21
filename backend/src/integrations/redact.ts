// Removes secrets from text before it is logged, stored, returned or sent to
// an external service.
//
// Used for every error message that comes from an external provider, because
// provider errors can echo request details (webhook URLs carry their secret
// in the path, SMTP errors can echo credentials), and for the text users paste
// into the developer assistant before it goes to Groq.

type Rule = { pattern: RegExp; replace: string | ((...groups: string[]) => string) };

export const REDACTED = "[redacted]";

// Order matters: whole blocks and URLs first, then token formats, then
// key = value pairs (which would otherwise only catch the first word).
const RULES: Rule[] = [
  // PEM private keys (whole block).
  { pattern: /-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z0-9 ]*PRIVATE KEY-----/g, replace: REDACTED },
  { pattern: /https:\/\/hooks\.slack\.com\/[^\s"'<>]+/gi, replace: REDACTED },
  { pattern: /https:\/\/(?:[a-z]+\.)?discord(?:app)?\.com\/api\/webhooks\/[^\s"'<>]+/gi, replace: REDACTED },
  // Password in a URL or connection string: scheme://user:password@host
  { pattern: /\b([a-z][a-z0-9+.-]*:\/\/[^\s:@/]+:)([^\s@/]+)@/gi, replace: (_m, head) => `${head}${REDACTED}@` },
  { pattern: /\bBearer\s+[A-Za-z0-9._~+/=-]{8,}/gi, replace: REDACTED },
  { pattern: /\bBasic\s+[A-Za-z0-9+/=]{8,}/gi, replace: REDACTED },
  { pattern: /\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}/g, replace: REDACTED }, // JWTs
  { pattern: /\bgh[pousr]_[A-Za-z0-9]{20,}\b/g, replace: REDACTED }, // GitHub classic and app tokens
  { pattern: /\bgithub_pat_[A-Za-z0-9_]{20,}\b/g, replace: REDACTED }, // GitHub fine-grained tokens
  { pattern: /\bxox[abposr]-[A-Za-z0-9-]{10,}\b/g, replace: REDACTED }, // Slack tokens
  { pattern: /\bgsk_[A-Za-z0-9]{20,}\b/g, replace: REDACTED }, // Groq keys
  { pattern: /\bsb_secret_[A-Za-z0-9_-]{10,}\b/g, replace: REDACTED }, // Supabase secret keys
  { pattern: /\bsk-[A-Za-z0-9_-]{20,}\b/g, replace: REDACTED }, // sk- style API keys
  { pattern: /\bAKIA[0-9A-Z]{16}\b/g, replace: REDACTED }, // AWS access key ids
  // key = value / key: value / "key": "value" for credential-like keys.
  {
    pattern: /\b(password|passwd|pwd|secret|client[_-]?secret|token|access[_-]?token|refresh[_-]?token|api[_-]?key|access[_-]?key|private[_-]?key|authorization)\b(["']?\s*[:=]\s*["']?)(?!\[redacted\])([^\s"',;&}]+)/gi,
    replace: (_m, key, sep) => `${key}${sep}${REDACTED}`
  }
];

// Returns the redacted text and how many values were removed.
export function redactSecretsCounted(
  text: string,
  extraSecrets: string[] = []
): { text: string; count: number } {
  let result = text;
  let count = 0;

  for (const secret of extraSecrets) {
    // Short values would redact ordinary words; real secrets are longer.
    if (secret && secret.length >= 6 && result.includes(secret)) {
      const parts = result.split(secret);
      count += parts.length - 1;
      result = parts.join(REDACTED);
    }
  }

  for (const rule of RULES) {
    result = result.replace(rule.pattern, (...args: unknown[]) => {
      count += 1;
      const groups = args.slice(0, -2).map((g) => (typeof g === "string" ? g : ""));
      return typeof rule.replace === "string" ? rule.replace : rule.replace(...groups);
    });
  }

  return { text: result, count };
}

export function redactSecrets(text: string, extraSecrets: string[] = []): string {
  return redactSecretsCounted(text, extraSecrets).text;
}

// Redacts, collapses whitespace and truncates (the notification_deliveries
// error_message column keeps at most 500 characters).
export function safeErrorMessage(
  text: string,
  maxLength = 500,
  extraSecrets: string[] = []
): string {
  const clean = redactSecrets(text, extraSecrets).replace(/\s+/g, " ").trim();
  return clean.length > maxLength ? `${clean.slice(0, maxLength - 3)}...` : clean;
}
