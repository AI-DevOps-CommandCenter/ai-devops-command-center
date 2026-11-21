import { join } from "node:path";
import { config } from "dotenv";

// Loads environment variables for local runs.
//
// Candidates, in priority order (dotenv never overrides a variable that is
// already set, so the first file that defines a variable wins, and real
// environment variables always win over files):
//   1. backend/.env
//   2. <repository root>/.env   (the project's git-ignored env file)
//
// The paths are resolved from this file's location, so they do not depend on
// the current working directory (src/config and dist/config sit at the same
// depth). Set BACKEND_SKIP_DOTENV=1 to skip file loading entirely (tests,
// CI, containers that inject variables directly).
const backendDir = join(import.meta.dirname, "..", "..");

export const ENV_FILE_CANDIDATES = [
  join(backendDir, ".env"),
  join(backendDir, "..", ".env")
];

if (process.env.BACKEND_SKIP_DOTENV !== "1") {
  config({ path: ENV_FILE_CANDIDATES, quiet: true });
}
