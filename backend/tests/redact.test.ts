import { describe, expect, it } from "vitest";

import { redactSecrets, redactSecretsCounted } from "../src/integrations/redact.js";

// Synthetic values only (none of these are real credentials).
describe("redactSecrets", () => {
  it.each([
    ["password=hunter2-xyz", "password=[redacted]"],
    ["PASSWORD: hunter2-xyz", "PASSWORD: [redacted]"],
    ['{"api_key": "abc123def456"}', '{"api_key": "[redacted]"}'],
    ["client_secret=s3cr3t-value", "client_secret=[redacted]"],
    ["token=abcdef123456", "token=[redacted]"],
    ["Authorization: Bearer abcdefgh12345678", "Authorization: [redacted]"],
    ["key gsk_" + "a".repeat(30), "key [redacted]"],
    ["jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.c2lnbmF0dXJlLXZhbHVl end", "jwt [redacted] end"],
    ["postgres://app:pa55word@db:5432/app", "postgres://app:[redacted]@db:5432/app"],
    ["redis://default:pa55word@cache:6379", "redis://default:[redacted]@cache:6379"],
    ["aws AKIAABCDEFGHIJKLMNOP", "aws [redacted]"],
    ["sb_secret_abcdefghijkl123", "[redacted]"],
    ["sk-" + "x".repeat(24), "[redacted]"],
    ["ghp_" + "a".repeat(36), "[redacted]"],
    ["-----BEGIN RSA PRIVATE KEY-----\nMIIEow\nabc\n-----END RSA PRIVATE KEY-----", "[redacted]"]
  ])("redacts %j", (input, expected) => {
    expect(redactSecrets(input)).toBe(expected);
  });

  it.each([
    "ERROR connection refused (127.0.0.1:5432)",
    "TypeError: Cannot read properties of undefined (reading 'id') at handler (app.js:42:7)",
    "GET https://api.example.test/v1/items 500 Internal Server Error",
    "tokens used: 1200",
    "password reset email sent"
  ])("keeps ordinary log text unchanged: %j", (input) => {
    expect(redactSecrets(input)).toBe(input);
  });

  it("counts every removed value once (Bearer inside Authorization counts once)", () => {
    const { text, count } = redactSecretsCounted("Authorization: Bearer abcdefgh12345678\npassword=x1y2z3w4");
    expect(text).toBe("Authorization: [redacted]\npassword=[redacted]");
    expect(count).toBe(2);
  });

  it("still redacts the extra secrets the senders pass in", () => {
    expect(redactSecrets("smtp auth failed for hunter22!", ["hunter22"])).toBe("smtp auth failed for [redacted]!");
  });
});
