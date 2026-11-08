import { vi } from "vitest";

// Shared mock functions for the `src/config/supabase.ts` module.
// Each test file registers them with vi.mock(...) so the real module (which
// would load .env and create real clients) is never evaluated.
export const supabaseMocks = {
  getUser: vi.fn(),
  createUserSupabaseClient: vi.fn()
};

export function supabaseModuleFactory() {
  return {
    supabase: {
      auth: {
        getUser: (...args: unknown[]) => supabaseMocks.getUser(...args)
      }
    },
    createUserSupabaseClient: (...args: unknown[]) =>
      supabaseMocks.createUserSupabaseClient(...args)
  };
}

export const TEST_USER = {
  id: "11111111-1111-4111-8111-111111111111",
  email: "test.user@example.test"
};

export const TEST_TOKEN = "test-user-jwt";

export function mockValidUser() {
  supabaseMocks.getUser.mockResolvedValue({
    data: { user: TEST_USER },
    error: null
  });
}
