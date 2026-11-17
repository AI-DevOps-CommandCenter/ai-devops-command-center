// Read-only service logs for the mobile app (S09), queried from Loki.
// The error filter is the one workflow 02 uses, so the app shows the lines
// the AI investigation read.

export class LogsUnavailableError extends Error {}

export const LOG_SERVICE_PATTERN = /^[a-z0-9][a-z0-9_.-]{0,62}$/i;
const ERROR_FILTER = '|~ "(?i)(error|exception|fatal|panic|critical|warn)"';

export interface LogLine {
  time: string;
  level: string | null;
  message: string;
  logger: string | null;
  raw: string;
}

export interface LokiClient {
  queryRange(logql: string, startNs: bigint, endNs: bigint, limit: number): Promise<Array<{ stream: Record<string, string>; values: Array<[string, string]> }>>;
}

export function createLokiClient(baseUrl: string, fetchImpl: typeof fetch = fetch, timeoutMs = 8000): LokiClient {
  const base = baseUrl.replace(/\/+$/, "");
  return {
    async queryRange(logql, startNs, endNs, limit) {
      const params = new URLSearchParams({
        query: logql,
        start: startNs.toString(),
        end: endNs.toString(),
        limit: String(limit),
        direction: "backward"
      });
      let res: Response;
      try {
        res = await fetchImpl(`${base}/loki/api/v1/query_range?${params.toString()}`, {
          signal: AbortSignal.timeout(timeoutMs)
        });
      } catch {
        throw new LogsUnavailableError("Loki is not reachable.");
      }
      const body = (await res.json().catch(() => null)) as
        | { status?: string; data?: { result?: unknown } }
        | null;
      if (!res.ok || body?.status !== "success" || !Array.isArray(body.data?.result)) {
        throw new LogsUnavailableError("Loki query failed.");
      }
      return body.data!.result as Array<{ stream: Record<string, string>; values: Array<[string, string]> }>;
    }
  };
}

// Parses one log line: structured JSON (sample-app, promtail) or plain text.
export function parseLogLine(tsNs: string, line: string, stream: Record<string, string>): LogLine {
  const time = new Date(Number(BigInt(tsNs) / 1_000_000n)).toISOString();
  try {
    const j = JSON.parse(line) as Record<string, unknown>;
    if (j && typeof j === "object") {
      const msg = typeof j.msg === "string" ? j.msg : typeof j.message === "string" ? j.message : line;
      const exc = typeof j.exc_info === "string" ? `\n${j.exc_info}` : "";
      return {
        time,
        level: typeof j.level === "string" ? j.level : stream.level ?? null,
        message: `${msg}${exc}`.slice(0, 4000),
        logger: typeof j.logger === "string" ? j.logger : null,
        raw: line.slice(0, 4000)
      };
    }
  } catch {
    // plain text line
  }
  return { time, level: stream.level ?? stream.detected_level ?? null, message: line.slice(0, 4000), logger: null, raw: line.slice(0, 4000) };
}

export async function getServiceLogs(
  loki: LokiClient,
  service: string,
  options: { minutes: number; errorsOnly: boolean; limit: number },
  nowMs = Date.now()
): Promise<LogLine[]> {
  const selector = `{service="${service}"}`;
  const logql = options.errorsOnly ? `${selector} ${ERROR_FILTER}` : selector;
  const endNs = BigInt(nowMs) * 1_000_000n;
  const startNs = endNs - BigInt(options.minutes) * 60n * 1_000_000_000n;
  const streams = await loki.queryRange(logql, startNs, endNs, options.limit);
  return streams
    .flatMap((s) => s.values.map(([ts, line]) => ({ ts, line, stream: s.stream })))
    .sort((a, b) => (BigInt(b.ts) > BigInt(a.ts) ? 1 : -1))
    .slice(0, options.limit)
    .map((e) => parseLogLine(e.ts, e.line, e.stream));
}
