import { beforeEach, vi } from "vitest";

// Safety net: tests must never reach a real Supabase project or any other
// remote service. Supabase is mocked in every test; if anything still tries
// to use fetch, the test fails loudly.
beforeEach(() => {
  vi.stubGlobal("fetch", () => {
    throw new Error("Network access is disabled in tests.");
  });
});
