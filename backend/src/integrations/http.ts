// Shared HTTP helper for outbound integrations (GitHub, Slack, Discord).
//
// - Every request has a timeout (AbortController).
// - Failures are classified once, so callers decide on retry/HTTP status by
//   `kind` and `retryable` instead of parsing error text.
// - `fetchImpl` is injectable. Tests pass a fake; production uses the global
//   fetch, resolved at call time (the test setup blocks the global fetch).

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export type HttpFailureKind =
  | "timeout"
  | "network"
  | "auth" // 401/403 that is not a rate limit
  | "not_found"
  | "rate_limited"
  | "client_error" // other 4xx
  | "server_error"; // 5xx

export class HttpRequestError extends Error {
  constructor(
    readonly kind: HttpFailureKind,
    message: string,
    readonly status?: number,
    readonly retryable = false,
    // Milliseconds the provider asked us to wait (Retry-After / rate-limit reset).
    readonly retryAfterMs?: number,
    // Parsed error response body, for providers that put an error code there.
    // Never put it into logs as is.
    readonly body?: unknown
  ) {
    super(message);
    this.name = "HttpRequestError";
  }
}

export interface HttpResponse {
  status: number;
  headers: Headers;
  body: unknown; // parsed JSON, the raw text, or null for an empty body
}

export const defaultFetch: FetchLike = (input, init) => globalThis.fetch(input, init);

// Parses Retry-After (seconds or an HTTP date). Returns milliseconds.
export function parseRetryAfter(value: string | null, now = Date.now()): number | undefined {
  if (!value) return undefined;

  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) return Math.ceil(seconds * 1000);

  const date = Date.parse(value);
  if (!Number.isNaN(date)) return Math.max(0, date - now);

  return undefined;
}

// GitHub-style headers: x-ratelimit-remaining: 0 and x-ratelimit-reset (unix seconds).
function rateLimitWaitMs(headers: Headers, now: number): number | undefined {
  const retryAfter = parseRetryAfter(headers.get("retry-after"), now);
  if (retryAfter !== undefined) return retryAfter;

  if (headers.get("x-ratelimit-remaining") === "0") {
    const reset = Number(headers.get("x-ratelimit-reset"));
    if (Number.isFinite(reset) && reset > 0) return Math.max(0, reset * 1000 - now);
    return 60_000;
  }

  return undefined;
}

function classifyStatus(response: HttpResponse, now: number): HttpRequestError {
  const { status, headers, body } = response;
  const waitMs = rateLimitWaitMs(headers, now);

  // GitHub signals primary and secondary rate limits with 403 or 429.
  if (status === 429 || (status === 403 && waitMs !== undefined)) {
    return new HttpRequestError("rate_limited", `Rate limited (HTTP ${status}).`, status, true, waitMs ?? 60_000, body);
  }
  if (status === 401 || status === 403) {
    return new HttpRequestError("auth", `Authentication rejected (HTTP ${status}).`, status, false, undefined, body);
  }
  if (status === 404) {
    return new HttpRequestError("not_found", "Resource not found (HTTP 404).", status, false, undefined, body);
  }
  if (status >= 500) {
    return new HttpRequestError("server_error", `Provider error (HTTP ${status}).`, status, true, waitMs, body);
  }
  return new HttpRequestError("client_error", `Request rejected (HTTP ${status}).`, status, false, undefined, body);
}

async function readBody(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return null;

  const type = response.headers.get("content-type") ?? "";
  if (type.includes("json")) {
    try {
      return JSON.parse(text) as unknown;
    } catch {
      return text;
    }
  }
  return text;
}

export interface HttpRequestOptions {
  method?: "GET" | "POST";
  headers?: Record<string, string>;
  json?: unknown;
  timeoutMs: number;
  fetchImpl?: FetchLike;
  // Clock used for rate-limit reset times (injectable for tests).
  now?: () => number;
}

// Sends one request. Resolves with the response for 2xx; throws
// HttpRequestError otherwise. Error messages never contain the URL, because
// webhook URLs carry their secret.
export async function httpRequest(url: string, options: HttpRequestOptions): Promise<HttpResponse> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), options.timeoutMs);
  const fetchImpl = options.fetchImpl ?? defaultFetch;

  let response: Response;
  try {
    response = await fetchImpl(url, {
      method: options.method ?? "GET",
      headers: {
        ...(options.json !== undefined ? { "Content-Type": "application/json" } : {}),
        ...options.headers
      },
      body: options.json !== undefined ? JSON.stringify(options.json) : undefined,
      signal: controller.signal,
      // Redirects are not followed: a 3xx is reported as a client error
      // instead of silently sending the request somewhere else.
      redirect: "manual"
    });
  } catch (error) {
    clearTimeout(timer);
    if (controller.signal.aborted) {
      throw new HttpRequestError("timeout", `No response within ${options.timeoutMs} ms.`, undefined, true);
    }
    throw new HttpRequestError("network", "Network error while contacting the provider.", undefined, true);
  }

  let body: unknown;
  try {
    body = await readBody(response);
  } catch {
    // Timeout or connection loss while the body was streaming.
    const kind = controller.signal.aborted ? "timeout" : "network";
    throw new HttpRequestError(kind, "The provider response could not be read.", response.status, true);
  } finally {
    clearTimeout(timer);
  }

  const result: HttpResponse = { status: response.status, headers: response.headers, body };

  if (response.status < 200 || response.status >= 300) {
    throw classifyStatus(result, (options.now ?? Date.now)());
  }

  return result;
}
