import { redactSecrets, redactSecretsCounted } from "../integrations/redact.js";

// Developer assistant (S23): explains a pasted log snippet or error message.
// It only explains: nothing is run or changed, and no command is suggested.
// Secrets are removed BEFORE the text goes to Groq, and the reply is redacted
// again. Neither the pasted text nor the reply is stored or logged.

export const MAX_INPUT_LENGTH = 8000;

export const ASSISTANT_SYSTEM_PROMPT = [
  "You are the developer assistant of a DevOps incident command center.",
  "The user pastes a log snippet or an error message. Explain it for a developer.",
  "Rules:",
  "1. Use only the pasted text. Do not invent log lines, versions, hosts or values.",
  "2. You only explain. Never write shell commands, scripts, code, SQL or configuration, and never tell the user to run something.",
  '   "next_checks" are things to look at (a log, a metric, a recent change, a setting), not commands.',
  "3. Some values were replaced with [redacted] before you saw them. Do not guess them.",
  "4. If the text is not a log or an error, say so in \"meaning\" and leave the lists empty.",
  "5. \"confidence\" is a number from 0 to 1.",
  "Reply with ONLY one JSON object, no extra text, in this exact shape:",
  '{"meaning": "", "likely_causes": [], "next_checks": [], "confidence": 0.0}'
].join("\n");

export interface AssistantClient {
  readonly model: string;
  // Returns the raw message content of the model reply.
  complete(system: string, user: string): Promise<string>;
}

export type AssistantErrorKind = "timeout" | "rate_limited" | "auth" | "unavailable" | "invalid_response";

export class AssistantError extends Error {
  constructor(public readonly kind: AssistantErrorKind, message: string) {
    super(message);
    this.name = "AssistantError";
  }
}

export interface Explanation {
  meaning: string;
  likely_causes: string[];
  next_checks: string[];
  confidence: number;
  redacted_count: number;
  model: string;
}

export const DEFAULT_GROQ_BASE_URL = "https://api.groq.com/openai/v1";
export const DEFAULT_GROQ_MODEL = "openai/gpt-oss-120b";

// The chat completions URL for a base URL. Accepts the documented base
// (https://api.groq.com/openai/v1) and also the bare host (https://api.groq.com),
// so the path is never missing or doubled.
export function groqChatUrl(baseUrl: string): string {
  const base = baseUrl.trim().replace(/\/+$/, "");
  const withApi = /\/openai\/v1$/.test(base) ? base : new URL(base).pathname === "/" || new URL(base).pathname === ""
    ? `${base}/openai/v1`
    : base;
  return `${withApi}/chat/completions`;
}

export interface GroqOptions {
  apiKey: string;
  model: string;
  baseUrl: string;
  timeoutMs: number;
  fetchImpl?: typeof fetch;
}

// Groq chat completions (OpenAI-compatible). Error messages never contain the
// request or the response body.
export function createGroqClient(options: GroqOptions): AssistantClient {
  const doFetch = options.fetchImpl ?? fetch;
  const url = groqChatUrl(options.baseUrl);

  return {
    model: options.model,
    async complete(system, user) {
      let res: Response;
      try {
        res = await doFetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${options.apiKey}` },
          body: JSON.stringify({
            model: options.model,
            temperature: 0.2,
            max_tokens: 900,
            response_format: { type: "json_object" },
            messages: [
              { role: "system", content: system },
              { role: "user", content: user }
            ]
          }),
          signal: AbortSignal.timeout(options.timeoutMs)
        });
      } catch (error) {
        const name = (error as { name?: string } | null)?.name;
        if (name === "TimeoutError" || name === "AbortError") {
          throw new AssistantError("timeout", "The AI service did not answer in time.");
        }
        throw new AssistantError("unavailable", "The AI service is not reachable.");
      }

      if (res.status === 429) throw new AssistantError("rate_limited", "The AI service is busy. Try again in a minute.");
      if (res.status === 401 || res.status === 403) {
        throw new AssistantError("auth", "The AI service rejected the configured key.");
      }
      if (res.status === 404) {
        // Groq answers 404 model_not_found for an unknown or retired model.
        const code = await res.json().then((b: { error?: { code?: unknown } }) => b?.error?.code).catch(() => undefined);
        if (code === "model_not_found") {
          throw new AssistantError(
            "unavailable",
            `The AI model "${options.model}" is not available. Set GROQ_MODEL in backend/.env (for example ${DEFAULT_GROQ_MODEL}).`
          );
        }
      }
      if (!res.ok) throw new AssistantError("unavailable", `The AI service answered HTTP ${res.status}.`);

      let body: unknown;
      try {
        body = await res.json();
      } catch {
        throw new AssistantError("invalid_response", "The AI service sent an unreadable answer.");
      }
      const content = (body as { choices?: { message?: { content?: unknown } }[] })?.choices?.[0]?.message?.content;
      if (typeof content !== "string" || content.trim() === "") {
        throw new AssistantError("invalid_response", "The AI service sent an empty answer.");
      }
      return content;
    }
  };
}

// Removes code blocks, inline code and lines that look like shell commands:
// the assistant explains, it never hands out commands.
export function stripCommands(text: string): string {
  return text
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/`[^`\n]*`/g, (m) => m.slice(1, -1).replace(/^\s*(\$|#|>|sudo\b)\s*/, ""))
    .split("\n")
    .filter((line) => !/^\s*(\$|sudo\s|>\s)/.test(line))
    .join("\n")
    .replace(/[ \t]+/g, " ")
    .trim();
}

function cleanText(value: unknown, max: number): string {
  if (typeof value !== "string") return "";
  const clean = redactSecrets(stripCommands(value));
  return clean.length > max ? `${clean.slice(0, max - 1)}…` : clean;
}

function cleanList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => cleanText(item, 300))
    .filter((item) => item.length > 0)
    .slice(0, 5);
}

export function parseExplanation(raw: string): Omit<Explanation, "redacted_count" | "model"> {
  let parsed: unknown;
  try {
    // Some models wrap the JSON in a code fence despite JSON mode.
    parsed = JSON.parse(raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, ""));
  } catch {
    throw new AssistantError("invalid_response", "The AI answer was not valid JSON.");
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new AssistantError("invalid_response", "The AI answer had an unexpected shape.");
  }
  const p = parsed as Record<string, unknown>;
  const meaning = cleanText(p.meaning, 1500);
  if (!meaning) throw new AssistantError("invalid_response", "The AI answer had no explanation.");
  const confidence = typeof p.confidence === "number" && Number.isFinite(p.confidence)
    ? Math.min(1, Math.max(0, p.confidence))
    : 0;
  return {
    meaning,
    likely_causes: cleanList(p.likely_causes),
    next_checks: cleanList(p.next_checks),
    confidence
  };
}

export async function explainText(client: AssistantClient, text: string): Promise<Explanation> {
  const { text: redacted, count } = redactSecretsCounted(text);
  const user = `Explain this log snippet or error message:\n\n${redacted}`;
  const raw = await client.complete(ASSISTANT_SYSTEM_PROMPT, user);
  return { ...parseExplanation(raw), redacted_count: count, model: client.model };
}

function envInt(env: NodeJS.ProcessEnv, name: string, fallback: number, min: number, max: number): number {
  const raw = env[name]?.trim();
  if (!raw) return fallback;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < min || n > max) throw new Error(`${name} must be an integer from ${min} to ${max}.`);
  return n;
}

// The assistant from the environment (GROQ_API_KEY, GROQ_MODEL,
// GROQ_API_BASE_URL, GROQ_TIMEOUT_MS). null when GROQ_API_KEY is not set.
// The key is read here only; it is never logged or returned.
export function assistantFromEnv(env: NodeJS.ProcessEnv = process.env, fetchImpl?: typeof fetch): AssistantClient | null {
  const apiKey = env.GROQ_API_KEY?.trim();
  if (!apiKey) return null;
  const baseUrl = env.GROQ_API_BASE_URL?.trim() || DEFAULT_GROQ_BASE_URL;
  if (!/^https:\/\//.test(baseUrl)) throw new Error("GROQ_API_BASE_URL must be an https URL.");
  return createGroqClient({
    apiKey,
    baseUrl,
    model: env.GROQ_MODEL?.trim() || DEFAULT_GROQ_MODEL,
    timeoutMs: envInt(env, "GROQ_TIMEOUT_MS", 25000, 1000, 60000),
    fetchImpl
  });
}
