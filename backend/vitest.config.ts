import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
    setupFiles: ["tests/setup.ts"],
    // Never load .env files during tests (see src/config/load-env.ts).
    env: {
      BACKEND_SKIP_DOTENV: "1"
    },
    restoreMocks: true,
    clearMocks: true
  }
});
