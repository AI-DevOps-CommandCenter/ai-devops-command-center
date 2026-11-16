#!/usr/bin/env bash
# Switch sample-app faults through its admin API, from inside the container
# (the admin API is not published to the host).
#
#   scripts/fault.sh errors [rate]       fail that share of requests (default 0.5)
#   scripts/fault.sh latency [rate]      slow that share of requests
#   scripts/fault.sh off                 clear the fault
#   scripts/fault.sh breaker open|closed open or close the circuit breaker
#   scripts/fault.sh status              show the current state
set -euo pipefail
export MSYS_NO_PATHCONV=1  # Git Bash on Windows: pass /admin/... paths unchanged
cd "$(dirname "$0")/.."

usage() {
  sed -n '5,9p' "$0"
  exit 2
}

admin() {  # admin METHOD PATH [JSON_BODY]
  docker compose exec -T sample-app python - "$1" "$2" "${3:-}" <<'PY'
import sys
import urllib.error
import urllib.request

method, path, body = sys.argv[1:4]
request = urllib.request.Request(
    "http://127.0.0.1:8000" + path,
    data=body.encode() or None,
    method=method,
    headers={"Content-Type": "application/json"},
)
try:
    print(urllib.request.urlopen(request, timeout=5).read().decode())
except urllib.error.HTTPError as error:
    print(f"HTTP {error.code}: {error.read().decode()}")
    sys.exit(1)
PY
}

case "${1:-}" in
  errors | latency) admin POST /admin/fault "{\"mode\": \"$1\", \"rate\": ${2:-0.5}}" ;;
  off) admin POST /admin/fault '{"mode": "off"}' ;;
  breaker)
    case "${2:-}" in
      open) admin POST /admin/circuit-breaker '{"open": true}' ;;
      closed) admin POST /admin/circuit-breaker '{"open": false}' ;;
      *) usage ;;
    esac
    ;;
  status) admin GET /admin/fault ;;
  *) usage ;;
esac
