// Read-only service metrics for the mobile app, queried from Prometheus.
// The PromQL matches the queries workflow 03 / 07 use
// (monitoring/n8n-integration.env), so the app shows what the AI saw.

export interface PrometheusClient {
  query(promql: string): Promise<PromSample[]>;
  queryRange(promql: string, startSec: number, endSec: number, stepSec: number): Promise<PromSeries[]>;
}

export interface PromSample {
  metric: Record<string, string>;
  value: number;
}

export interface PromSeries {
  metric: Record<string, string>;
  values: Array<[number, number]>;
}

export class MetricsUnavailableError extends Error {}

// Service names go into PromQL label matchers, so only plain names are accepted.
export const SERVICE_NAME_PATTERN = /^[a-z0-9][a-z0-9_.-]{0,62}$/i;

const toNumber = (v: unknown) => {
  const n = typeof v === "string" ? Number(v) : NaN;
  return Number.isFinite(n) ? n : NaN;
};

export function createPrometheusClient(
  baseUrl: string,
  fetchImpl: typeof fetch = fetch,
  timeoutMs = 5000
): PrometheusClient {
  const base = baseUrl.replace(/\/+$/, "");

  async function get(path: string, params: Record<string, string>) {
    const url = `${base}${path}?${new URLSearchParams(params).toString()}`;
    let res: Response;
    try {
      res = await fetchImpl(url, { signal: AbortSignal.timeout(timeoutMs) });
    } catch {
      throw new MetricsUnavailableError("Prometheus is not reachable.");
    }
    const body = (await res.json().catch(() => null)) as
      | { status?: string; data?: { result?: unknown[] } }
      | null;
    if (!res.ok || body?.status !== "success" || !Array.isArray(body.data?.result)) {
      throw new MetricsUnavailableError("Prometheus query failed.");
    }
    return body.data!.result as Array<Record<string, unknown>>;
  }

  return {
    async query(promql) {
      const result = await get("/api/v1/query", { query: promql });
      return result.map((r) => ({
        metric: (r.metric ?? {}) as Record<string, string>,
        value: toNumber((r.value as unknown[] | undefined)?.[1])
      }));
    },
    async queryRange(promql, startSec, endSec, stepSec) {
      const result = await get("/api/v1/query_range", {
        query: promql,
        start: String(startSec),
        end: String(endSec),
        step: String(stepSec)
      });
      return result.map((r) => ({
        metric: (r.metric ?? {}) as Record<string, string>,
        values: ((r.values ?? []) as unknown[][]).map(
          ([t, v]) => [Number(t), toNumber(v)] as [number, number]
        )
      }));
    }
  };
}

const q = {
  errorRate: (s: string) =>
    `(sum(rate(http_requests_total{service="${s}",status=~"5.."}[2m])) or vector(0)) / sum(rate(http_requests_total{service="${s}"}[2m]))`,
  latencyP95: (s: string) =>
    `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{service="${s}"}[5m])))`,
  requestRate: (s: string) => `sum(rate(http_requests_total{service="${s}"}[5m]))`,
  // CPU as percent of one core.
  cpu: (s: string) => `sum(rate(process_cpu_seconds_total{service="${s}"}[2m])) * 100`,
  memory: (s: string) => `sum(process_resident_memory_bytes{service="${s}"})`
};

export const THRESHOLDS = { errorRate: 0.05, latencyP95Seconds: 0.5 };

const clean = (n: number | undefined) => (n === undefined || !Number.isFinite(n) ? null : n);

export interface ServiceHealth {
  service: string;
  up: boolean;
  error_rate: number | null;
  status: "healthy" | "warning" | "down";
}

export async function listServiceHealth(prom: PrometheusClient): Promise<ServiceHealth[]> {
  const [up, errors] = await Promise.all([
    prom.query("max by (service) (up)"),
    prom.query(
      `(sum by (service) (rate(http_requests_total{status=~"5.."}[2m])) or (sum by (service) (rate(http_requests_total[2m])) * 0)) / sum by (service) (rate(http_requests_total[2m]))`
    )
  ]);
  const errorBy = new Map(errors.map((e) => [e.metric.service, e.value]));
  return up
    .filter((u) => u.metric.service)
    .map((u) => {
      const isUp = u.value === 1;
      const err = clean(errorBy.get(u.metric.service));
      return {
        service: u.metric.service,
        up: isUp,
        error_rate: err,
        status: !isUp ? "down" : err !== null && err >= THRESHOLDS.errorRate ? "warning" : "healthy"
      } satisfies ServiceHealth;
    })
    .sort((a, b) => a.service.localeCompare(b.service));
}

export interface MetricSeries {
  current: number | null;
  points: Array<{ t: number; v: number | null }>;
}

export interface ServiceMetrics {
  service: string;
  window_minutes: number;
  thresholds: typeof THRESHOLDS;
  error_rate: MetricSeries;
  latency_p95_seconds: MetricSeries;
  request_rate: MetricSeries;
  cpu_percent: MetricSeries;
  memory_bytes: MetricSeries;
}

export async function getServiceMetrics(
  prom: PrometheusClient,
  service: string,
  windowMinutes = 60,
  nowSec = Math.floor(Date.now() / 1000)
): Promise<ServiceMetrics | null> {
  const known = await prom.query(`max by (service) (up{service="${service}"})`);
  if (known.length === 0) return null;

  const step = Math.max(15, Math.floor((windowMinutes * 60) / 30)); // ~30 points
  const start = nowSec - windowMinutes * 60;

  async function series(promql: string): Promise<MetricSeries> {
    const [now, range] = await Promise.all([
      prom.query(promql),
      prom.queryRange(promql, start, nowSec, step)
    ]);
    return {
      current: clean(now[0]?.value),
      points: (range[0]?.values ?? []).map(([t, v]) => ({ t, v: clean(v) }))
    };
  }

  const [error_rate, latency_p95_seconds, request_rate, cpu_percent, memory_bytes] = await Promise.all([
    series(q.errorRate(service)),
    series(q.latencyP95(service)),
    series(q.requestRate(service)),
    series(q.cpu(service)),
    series(q.memory(service))
  ]);

  return {
    service,
    window_minutes: windowMinutes,
    thresholds: THRESHOLDS,
    error_rate,
    latency_p95_seconds,
    request_rate,
    cpu_percent,
    memory_bytes
  };
}
