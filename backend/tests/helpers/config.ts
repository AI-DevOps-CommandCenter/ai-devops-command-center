import type { ServerConfig } from "../../src/config/env.js";

export function testConfig(overrides: Partial<ServerConfig> = {}): ServerConfig {
  return {
    port: 0,
    corsOrigins: ["https://allowed.example.test"],
    rateLimitWindowMs: 60_000,
    rateLimitMax: 1000,
    trustProxy: 0,
    ...overrides
  };
}
