#!/usr/bin/env bash
# Add a random EXECUTOR_SIGNING_SECRET to monitoring/.env (gitignored) if it is
# not there yet. The value is NOT printed. n8n needs the same value to sign its
# calls to the executor; copy it from monitoring/.env into automation/.env.
set -euo pipefail
cd "$(dirname "$0")/.."

if grep -q '^EXECUTOR_SIGNING_SECRET=.\+' .env 2>/dev/null; then
  echo "EXECUTOR_SIGNING_SECRET is already set in monitoring/.env."
  exit 0
fi

secret=$(python -c "import secrets; print(secrets.token_urlsafe(48))")
printf 'EXECUTOR_SIGNING_SECRET=%s\n' "$secret" >> .env
echo "Added EXECUTOR_SIGNING_SECRET to monitoring/.env. Recreate the executor: docker compose up -d executor"
