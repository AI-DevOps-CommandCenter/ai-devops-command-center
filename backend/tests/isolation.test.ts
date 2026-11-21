import { describe, expect, it, vi } from "vitest";

import {
  supabaseMocks,
  supabaseModuleFactory
} from "./helpers/mock-supabase-module.js";

vi.mock("../src/config/supabase.js", () => supabaseModuleFactory());

// Proves the test environment cannot reach a real Supabase project.
describe("test isolation", () => {
  it("replaces the real Supabase config module with the mock", async () => {
    const mod = await import("../src/config/supabase.js");

    expect(Object.keys(mod).sort()).toEqual([
      "createUserSupabaseClient",
      "supabase"
    ]);

    supabaseMocks.getUser.mockResolvedValue({ data: { user: null }, error: null });
    await mod.supabase.auth.getUser("probe-token");

    expect(supabaseMocks.getUser).toHaveBeenCalledWith("probe-token");
  });

  it("blocks network access through fetch", () => {
    expect(() => fetch("https://example.test")).toThrow(
      "Network access is disabled in tests."
    );
  });

  it("disables .env loading for the test run", () => {
    expect(process.env.BACKEND_SKIP_DOTENV).toBe("1");
  });
});
