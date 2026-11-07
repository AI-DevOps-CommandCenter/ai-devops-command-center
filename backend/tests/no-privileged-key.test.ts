import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";

// Guard for decision D-001: no runtime service-role usage in backend code.
// Scans every source file for privileged-key identifiers.
const SRC_DIR = join(import.meta.dirname, "..", "src");
const FORBIDDEN = /service[_-]?role|SERVICE_ROLE|sb_secret_[A-Za-z0-9]/;

function listSourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? listSourceFiles(path) : [path];
  });
}

describe("no privileged Supabase key in backend source (D-001)", () => {
  it("contains no service-role identifiers", () => {
    const offenders = listSourceFiles(SRC_DIR)
      .filter((file) => file.endsWith(".ts"))
      .filter((file) => {
        const content = readFileSync(file, "utf8");
        // Allow the literal used by the key guard's own prefix check.
        return FORBIDDEN.test(content.replaceAll('"sb_secret_"', '""'));
      })
      .map((file) => relative(SRC_DIR, file));

    expect(offenders).toEqual([]);
  });
});
