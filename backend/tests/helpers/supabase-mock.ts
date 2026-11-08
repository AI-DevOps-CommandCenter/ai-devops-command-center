// Minimal, network-free stand-ins for the Supabase JS client used in tests.

export interface MockResult {
  data?: unknown;
  error?: unknown;
  count?: number | null;
}

export interface RecordedCall {
  table: string;
  method: string;
  args: unknown[];
}

// A chainable query builder: every method returns the builder, and awaiting
// it resolves to the configured result (like PostgREST builders).
function createQueryBuilder(
  table: string,
  result: MockResult,
  calls: RecordedCall[]
): unknown {
  const builder: unknown = new Proxy(
    {},
    {
      get(_target, prop) {
        if (prop === "then") {
          return (
            resolve: (value: MockResult) => unknown,
            reject: (reason: unknown) => unknown
          ) =>
            Promise.resolve({ data: null, error: null, ...result }).then(
              resolve,
              reject
            );
        }

        return (...args: unknown[]) => {
          calls.push({ table, method: String(prop), args });
          return builder;
        };
      }
    }
  );

  return builder;
}

// Creates a fake user-scoped client. `results` maps a table name to one
// result (reused) or a queue of results (consumed in order). Database
// function results use the key `rpc:<function name>`.
export function createMockUserClient(
  results: Record<string, MockResult | MockResult[]> = {}
) {
  const calls: RecordedCall[] = [];
  const queues = new Map<string, MockResult[]>();

  for (const [table, value] of Object.entries(results)) {
    queues.set(table, Array.isArray(value) ? [...value] : [value]);
  }

  const next = (key: string): MockResult => {
    const queue = queues.get(key) ?? [{ data: null, error: null }];
    return queue.length > 1 ? queue.shift()! : queue[0];
  };

  const client = {
    from(table: string) {
      const result = next(table);
      calls.push({ table, method: "from", args: [table] });
      return createQueryBuilder(table, result, calls);
    },
    rpc(fn: string, args: unknown) {
      const key = `rpc:${fn}`;
      calls.push({ table: key, method: "rpc", args: [args] });
      return Promise.resolve({ data: null, error: null, ...next(key) });
    }
  };

  return { client, calls };
}

export function callsFor(calls: RecordedCall[], table: string, method: string) {
  return calls.filter((call) => call.table === table && call.method === method);
}
