import { describe, expect, it } from "vitest";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

import { mapDbError } from "../src/lib/db-errors.js";
import {
  loadAutomationEnv,
  loadMachineEnv
} from "../src/config/machine.js";
// Guards for the database-function integration (decisions A2/A3/A7):
// - no direct writes to the workflow tables or the audit log in src/;
// - every rpc() call uses a function and parameter names that exist in the
//   migrations (supabase/migrations), so signatures cannot drift silently.

const SRC_DIR = join(import.meta.dirname, "..", "src");
const MIGRATIONS_DIR = join(import.meta.dirname, "..", "..", "supabase", "migrations");

function listFiles(dir: string, ext: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) return listFiles(full, ext);
    return full.endsWith(ext) ? [full] : [];
  });
}

const sources = listFiles(SRC_DIR, ".ts").map((file) => ({
  file: relative(SRC_DIR, file),
  text: readFileSync(file, "utf8")
}));

const migrationSql = listFiles(MIGRATIONS_DIR, ".sql")
  .map((file) => readFileSync(file, "utf8"))
  .join("\n");

// Parameter names of public.<fn>(...) as created in the migrations.
function migrationParams(fn: string): string[] | null {
  const match = new RegExp(
    `CREATE (?:OR REPLACE )?FUNCTION public\\.${fn}\\(([\\s\\S]*?)\\)\\s*RETURNS`,
    "i"
  ).exec(migrationSql);
  if (!match) return null;
  // Every "<name> <type> [DEFAULT ...]" entry; names need not start with p_
  // (e.g. admin_update_user_role(target_user_id, new_role)).
  return [...match[1].matchAll(/(?:^|,)\s*(\w+)\s+[A-Za-z]/g)].map((m) => m[1]);
}

// rpc("<fn>", { a: ..., b: ... }) calls in the source.
const rpcCalls = sources.flatMap(({ file, text }) =>
  [...text.matchAll(/\.rpc\("(\w+)",\s*\{([\s\S]*?)\}\s*\)/g)].map((m) => ({
    file,
    fn: m[1],
    keys: [...m[2].matchAll(/(\w+)\s*:/g)].map((k) => k[1])
  }))
);

describe("database-function integration guards", () => {
  it("never writes approvals, playbook_runs, remediation_executions or audit_logs directly", () => {
    const offenders = sources.flatMap(({ file, text }) =>
      [
        ...text.matchAll(
          /\.from\(\s*"(approvals|playbook_runs|remediation_executions|audit_logs)"\s*\)\s*\.(insert|update|upsert|delete)\(/g
        )
      ].map((m) => `${file}: ${m[1]}.${m[2]}`)
    );

    expect(offenders).toEqual([]);
  });

  it("has no backend audit writer left (the database audits, A7)", () => {
    const offenders = sources
      .filter(({ text }) => /createAuditLog/.test(text))
      .map(({ file }) => file);

    expect(offenders).toEqual([]);
  });

  it("uses all six workflow functions", () => {
    const used = new Set(rpcCalls.map((call) => call.fn));

    for (const fn of [
      "request_playbook_run",
      "decide_approval",
      "cancel_approval",
      "cancel_playbook_run",
      "start_playbook_run",
      "complete_playbook_run"
    ]) {
      expect(used.has(fn), fn).toBe(true);
    }
  });

  it("calls every function with exactly the parameter names defined in the migrations", () => {
    expect(rpcCalls.length).toBeGreaterThan(0);

    for (const call of rpcCalls) {
      const params = migrationParams(call.fn);
      expect(params, `${call.fn} is not defined in supabase/migrations`).not.toBeNull();
      // Guard against a vacuous pass if either side failed to parse.
      expect(params!.length, `${call.fn}: no parameters parsed from SQL`).toBeGreaterThan(0);
      expect(call.keys.length, `${call.file}: ${call.fn}: no arguments parsed`).toBeGreaterThan(0);
      expect([...call.keys].sort(), `${call.file}: ${call.fn}`).toEqual([...params!].sort());
    }
  });
});

describe("mapDbError()", () => {
  it("passes through database function messages with their HTTP status", () => {
    expect(mapDbError({ code: "DC401", message: "Authentication required." })).toEqual({
      status: 401,
      message: "Authentication required."
    });
    expect(mapDbError({ code: "DC403", message: "x" })?.status).toBe(403);
    expect(mapDbError({ code: "DC404", message: "x" })?.status).toBe(404);
    expect(mapDbError({ code: "DC409", message: "x" })?.status).toBe(409);
    expect(mapDbError({ code: "DC422", message: "x" })?.status).toBe(400);
  });

  it("hides PostgreSQL details behind generic messages", () => {
    expect(mapDbError({ code: "23505", message: "duplicate key value violates unique constraint \"x\"" }))
      .toEqual({ status: 409, message: "Duplicate request." });
    expect(mapDbError({ code: "42501", message: "permission denied for table approvals" }))
      .toEqual({ status: 403, message: "You do not have permission to perform this action." });
    expect(mapDbError({ code: "23514", message: "check constraint" })?.status).toBe(400);
  });

  it("returns null for unknown errors (callers answer 500)", () => {
    expect(mapDbError(new Error("boom"))).toBeNull();
    expect(mapDbError({ code: "XX000", message: "internal" })).toBeNull();
    expect(mapDbError(null)).toBeNull();
  });
});

describe("loadMachineEnv()", () => {
  const SECRET = "test-only-machine-secret-0123456789abcdef";

  it("is disabled when nothing is configured", () => {
    expect(loadMachineEnv({})).toBeNull();
  });

  it("requires all three variables and never echoes values", () => {
    expect(() => loadMachineEnv({ MACHINE_SIGNING_SECRET: SECRET })).toThrow(
      /missing AUTOMATION_EMAIL, AUTOMATION_PASSWORD/
    );
    try {
      loadMachineEnv({ MACHINE_SIGNING_SECRET: SECRET });
    } catch (error) {
      expect((error as Error).message).not.toContain(SECRET);
    }
  });

  it("rejects a short signing secret", () => {
    expect(() =>
      loadMachineEnv({
        MACHINE_SIGNING_SECRET: "short",
        AUTOMATION_EMAIL: "automation@example.test",
        AUTOMATION_PASSWORD: "synthetic"
      })
    ).toThrow(/at least 32/);
  });

  it("accepts a complete configuration", () => {
    expect(
      loadMachineEnv({
        MACHINE_SIGNING_SECRET: SECRET,
        AUTOMATION_EMAIL: "automation@example.test",
        AUTOMATION_PASSWORD: "synthetic"
      })
    ).toEqual({
      signingSecret: SECRET,
      automationEmail: "automation@example.test",
      automationPassword: "synthetic"
    });
  });
});
describe("loadAutomationEnv()", () => {
  it("is disabled when neither credential is configured", () => {
    expect(loadAutomationEnv({})).toBeNull();
  });

  it("requires both automation credentials", () => {
    expect(() =>
      loadAutomationEnv({
        AUTOMATION_EMAIL: "automation@example.test"
      })
    ).toThrow(/missing AUTOMATION_PASSWORD/);

    expect(() =>
      loadAutomationEnv({
        AUTOMATION_PASSWORD: "synthetic"
      })
    ).toThrow(/missing AUTOMATION_EMAIL/);
  });

  it("does not reveal credential values in errors", () => {
    const password = "test-only-secret-password";

    try {
      loadAutomationEnv({
        AUTOMATION_PASSWORD: password
      });
    } catch (error) {
      expect((error as Error).message).not.toContain(password);
    }
  });

  it("accepts both automation credentials without a machine signing secret", () => {
    expect(
      loadAutomationEnv({
        AUTOMATION_EMAIL: "automation@example.test",
        AUTOMATION_PASSWORD: "synthetic"
      })
    ).toEqual({
      automationEmail: "automation@example.test",
      automationPassword: "synthetic"
    });
  });
});