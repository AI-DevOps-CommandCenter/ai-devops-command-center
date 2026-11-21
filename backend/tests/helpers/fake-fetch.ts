// A scripted stand-in for fetch: records every request and answers from a
// queue. Network-free.

export interface FakeReply {
  status?: number;
  json?: unknown;
  text?: string;
  headers?: Record<string, string>;
  // Simulate a network failure (fetch rejects).
  networkError?: boolean;
  // Never answer; the request ends only when aborted (timeout tests).
  hang?: boolean;
}

export interface RecordedRequest {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: unknown;
}

export function createFakeFetch(replies: FakeReply[] | ((url: string) => FakeReply)) {
  const requests: RecordedRequest[] = [];
  const queue = Array.isArray(replies) ? [...replies] : null;

  const fetchImpl = async (input: string, init: RequestInit = {}): Promise<Response> => {
    const headers = Object.fromEntries(
      Object.entries((init.headers ?? {}) as Record<string, string>).map(([k, v]) => [k.toLowerCase(), v])
    );
    requests.push({
      url: input,
      method: init.method ?? "GET",
      headers,
      body: typeof init.body === "string" ? JSON.parse(init.body) : undefined
    });

    const reply = queue ? queue.shift() ?? { status: 500, text: "no scripted reply" } : (replies as (url: string) => FakeReply)(input);

    if (reply.hang) {
      return new Promise<Response>((_, reject) => {
        init.signal?.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
      });
    }
    if (reply.networkError) throw new TypeError("fetch failed");

    const isJson = reply.json !== undefined;
    return new Response(isJson ? JSON.stringify(reply.json) : reply.text ?? "", {
      status: reply.status ?? 200,
      headers: { ...(isJson ? { "content-type": "application/json" } : { "content-type": "text/plain" }), ...reply.headers }
    });
  };

  return { fetchImpl, requests };
}
