#!/usr/bin/env bash
# Create the random token Alertmanager sends to n8n (Authorization: Bearer <token>).
# It is written to alertmanager/secrets/n8n-token (gitignored) and NOT printed.
# Put the same value in the n8n credential "Alertmanager Webhook Token" as
# "Bearer <token>".
#
#   scripts/create-n8n-token.sh           create it if it does not exist
#   scripts/create-n8n-token.sh --force   replace it (n8n must be updated too)
set -euo pipefail
cd "$(dirname "$0")/.."

token_file=alertmanager/secrets/n8n-token
if [[ -f "$token_file" && "${1:-}" != "--force" ]]; then
  echo "$token_file already exists; use --force to replace it."
  exit 0
fi

python -c "import secrets; print(secrets.token_urlsafe(48), end='')" > "$token_file"
echo "Wrote $token_file. Copy its content into the n8n credential (Value: Bearer <token>)."
