// Removes secrets from text before it is logged, stored or returned.
//
// Used for every error message that comes from an external provider, because
// provider errors can echo request details (webhook URLs carry their secret
// in the path, SMTP errors can echo credentials).

const SECRET_PATTERNS: RegExp[] = [
  /https:\/\/hooks\.slack\.com\/[^\s"'<>]+/gi,
  /https:\/\/(?:[a-z]+\.)?discord(?:app)?\.com\/api\/webhooks\/[^\s"'<>]+/gi,
  /\bgh[pousr]_[A-Za-z0-9]{20,}\b/g, // GitHub classic and app tokens
  /\bgithub_pat_[A-Za-z0-9_]{20,}\b/g, // GitHub fine-grained tokens
  /\bxox[abposr]-[A-Za-z0-9-]{10,}\b/g, // Slack tokens
  /\bBearer\s+[A-Za-z0-9._~+/=-]{8,}/gi,
  /\bBasic\s+[A-Za-z0-9+/=]{8,}/gi
];

export const REDACTED = "[redacted]";

export function redactSecrets(text: string, extraSecrets: string[] = []): string {
  let result = text;

  for (const secret of extraSecrets) {
    // Short values would redact ordinary words; real secrets are longer.
    if (secret && secret.length >= 6) {
      result = result.split(secret).join(REDACTED);
    }
  }

  for (const pattern of SECRET_PATTERNS) {
    result = result.replace(pattern, REDACTED);
  }

  return result;
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
