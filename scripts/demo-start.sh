#!/usr/bin/env bash
# Starts everything for the local demo (Windows, Git Bash).
#
#   bash scripts/demo-start.sh
#
# 1. checks that Docker Desktop is running
# 2. starts n8n (automation/, project ccdemo)
# 3. starts the monitoring stack and the playbook executor (monitoring/)
# 4. warns about an open (not resolved) sample-app alert incident: the next
#    deploy-bad would attach to it instead of creating a new incident (read-only)
# 5. starts the backend on http://localhost:3000 (no watch mode)
# 6. serves the EXISTING web build (mobile/build/web) on http://127.0.0.1:8080
#    (it does not rebuild the web app)
# 7. runs `adb reverse tcp:3000 tcp:3000` for every connected phone
#
# Safe to run again: anything already running is left as it is.
# Logs: .demo/backend.log, .demo/web.log. Stop everything with scripts/demo-stop.sh.
# No secrets here: the backend, n8n and the executor read their own .env files.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT=$(pwd)
LOG_DIR="$ROOT/.demo"
mkdir -p "$LOG_DIR"

READY=()
FAILED=()
WARNINGS=()
ok()   { READY+=("$1");    echo "  OK    $1"; }
fail() { FAILED+=("$1");   echo "  FAIL  $1"; }
warn() { WARNINGS+=("$1"); echo "  WARN  $1"; }
step() { echo; echo "== $1"; }

# wait_http URL SECONDS: true once URL answers 2xx
wait_http() {
  local url=$1 secs=$2 i
  for ((i = 0; i < secs; i += 3)); do
    curl -fsS -o /dev/null --max-time 3 "$url" 2>/dev/null && return 0
    sleep 3
  done
  return 1
}

# Windows PIDs listening on a TCP port
port_pids() {
  netstat -ano 2>/dev/null | tr -d '\r' \
    | awk -v p=":$1" '$1 == "TCP" && $4 == "LISTENING" && substr($2, length($2) - length(p) + 1) == p { print $5 }' \
    | sort -u
}

# start_hidden NAME WORKDIR EXE ARG...: starts a Windows process that keeps
# running after this window is closed; output goes to .demo/NAME.log
start_hidden() {
  local name=$1 wd exe=$3 out err args="" a
  wd=$(cygpath -w "$2")
  out=$(cygpath -w "$LOG_DIR/$name.log")
  err=$(cygpath -w "$LOG_DIR/$name.err.log")
  shift 3
  for a in "$@"; do args+="'$a',"; done
  args=${args%,}
  powershell.exe -NoProfile -NonInteractive -Command \
    "Start-Process -FilePath '$exe' -ArgumentList @($args) -WorkingDirectory '$wd' -WindowStyle Hidden -RedirectStandardOutput '$out' -RedirectStandardError '$err'" \
    >/dev/null
}

find_adb() {
  if command -v adb >/dev/null 2>&1; then echo adb; return 0; fi
  local p="${LOCALAPPDATA:-}/Android/Sdk/platform-tools/adb.exe"
  if [ -n "${LOCALAPPDATA:-}" ] && [ -f "$(cygpath -u "$p")" ]; then cygpath -u "$p"; return 0; fi
  return 1
}

# ---------------------------------------------------------------- 1. Docker
step "1/7 Docker Desktop"
DOCKER_OK=0
if ! command -v docker >/dev/null 2>&1; then
  fail "Docker CLI not found. Install/start Docker Desktop."
elif docker info >/dev/null 2>&1; then
  DOCKER_OK=1
  ok "Docker Desktop is running"
else
  fail "Docker Desktop is not running. Start it, wait for 'Engine running', then run this script again."
fi

# ---------------------------------------------------------------- 2. n8n
step "2/7 n8n"
if [ $DOCKER_OK -eq 1 ]; then
  if (cd automation && docker compose -p ccdemo up -d) >"$LOG_DIR/compose-n8n.log" 2>&1; then
    if wait_http http://127.0.0.1:5678/healthz 90; then
      ok "n8n            http://localhost:5678"
    else
      fail "n8n container started but http://localhost:5678 does not answer (docker logs n8n)"
    fi
  else
    fail "n8n did not start (see .demo/compose-n8n.log)"
  fi
else
  fail "n8n skipped (Docker is not running)"
fi

# ---------------------------------------------------------------- 3. monitoring + executor
step "3/7 Monitoring stack + executor"
if [ $DOCKER_OK -eq 1 ]; then
  if ! grep -Eq '^[[:space:]]*EXECUTOR_SIGNING_SECRET=.{32,}' monitoring/.env 2>/dev/null; then
    warn "monitoring/.env has no EXECUTOR_SIGNING_SECRET: the executor will answer 503 (see docs/SETUP.md)"
  fi
  [ -s monitoring/alertmanager/secrets/n8n-token ] \
    || warn "monitoring/alertmanager/secrets/n8n-token is missing: alerts will not reach n8n"
  : >"$LOG_DIR/compose-monitoring.log"
  if ! docker image inspect dc-sample-app:stable dc-sample-app:v2-bad >/dev/null 2>&1; then
    echo "  building the sample-app release images (needed for deploy-bad and rollback)..."
    bash monitoring/scripts/release.sh build >>"$LOG_DIR/compose-monitoring.log" 2>&1 \
      || warn "release.sh build failed (see .demo/compose-monitoring.log)"
  fi
  if (cd monitoring && docker compose up -d) >>"$LOG_DIR/compose-monitoring.log" 2>&1; then
    check() {  # check NAME PROBE_PATH PORT
      if wait_http "http://127.0.0.1:$3$2" 90; then ok "$(printf '%-14s http://localhost:%s' "$1" "$3")"
      else fail "$1 does not answer on port $3 (cd monitoring && docker compose ps)"; fi
    }
    check Prometheus   /-/ready 9090
    check Alertmanager /-/ready 9093
    check Loki         /ready   3100
    check Executor     /health  9095
    status=$(bash monitoring/scripts/release.sh status 2>/dev/null)
    echo "$status" | sed 's/^/        /'
    if echo "$status" | grep -q 'version=v2'; then
      warn "sample-app is still on v2-bad from an earlier run: run 'bash monitoring/scripts/release.sh reset' and wait ~6 min"
    fi
    if [ "$(echo "$status" | grep -c '^dc-sample-app')" -gt 1 ]; then
      warn "scaled replicas are still there: run 'bash monitoring/scripts/release.sh reset'"
    fi
    active=$(curl -fsS --max-time 5 'http://127.0.0.1:9093/api/v2/alerts?active=true&silenced=false&inhibited=false' 2>/dev/null \
      | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{console.log(JSON.parse(s).length)}catch{console.log('?')}})")
    if [ "${active:-?}" = "0" ]; then
      ok "No active alerts (ready for deploy-bad)"
    elif [ "${active:-?}" != "?" ]; then
      warn "$active alert(s) still active from an earlier run. Run 'bash monitoring/scripts/release.sh reset' and wait until http://localhost:9093 shows none"
    fi
  else
    fail "Monitoring stack did not start (see .demo/compose-monitoring.log)"
  fi
else
  fail "Monitoring + executor skipped (Docker is not running)"
fi

# ---------------------------------------------------------------- 4. open alert incidents
step "4/7 Open alert incidents (read-only)"
open_out=$(node scripts/check-open-alert-incidents.mjs 2>&1)
case $? in
  0) ok "No open sample-app alert incident (deploy-bad will create a new one)" ;;
  3)
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      id=${line%% |*}
      env_field=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
      if [ "$env_field" = "test" ]; then
        how="it is hidden in the app (environment = test), so resolve it in the Supabase SQL editor"
      else
        how="open it in the app and use 'Mark resolved' on S05"
      fi
      warn "OPEN alert incident $id (${line#* | }). Resolve it BEFORE deploy-bad: $how. Otherwise the new alert attaches to it and no new incident is created"
    done <<<"$open_out"
    ;;
  *) warn "Could not check for open alert incidents: $open_out" ;;
esac

# ---------------------------------------------------------------- 5. backend
step "5/7 Backend"
if curl -fsS -o /dev/null --max-time 3 http://127.0.0.1:3000/ 2>/dev/null; then
  ok "Backend        http://localhost:3000 (was already running)"
elif [ -n "$(port_pids 3000)" ]; then
  fail "Port 3000 is taken but the backend does not answer. Run scripts/demo-stop.sh, then this script again"
elif [ ! -f backend/.env ]; then
  fail "backend/.env is missing (see docs/SETUP.md)"
elif [ ! -d backend/node_modules/tsx ]; then
  fail "backend/node_modules is missing: run 'cd backend && npm ci' first"
else
  : >"$LOG_DIR/backend.log"; : >"$LOG_DIR/backend.err.log"
  start_hidden backend "$ROOT/backend" node --import tsx src/server.ts
  if wait_http http://127.0.0.1:3000/ 60; then
    ok "Backend        http://localhost:3000"
  else
    fail "Backend did not start in 60 s. Last lines of .demo/backend.err.log:"
    tail -n 15 "$LOG_DIR/backend.err.log" 2>/dev/null | sed 's/^/        /'
  fi
fi

# ---------------------------------------------------------------- 6. web app
step "6/7 Web app (existing build, not rebuilt)"
if curl -fsS -o /dev/null --max-time 3 http://127.0.0.1:8080/ 2>/dev/null; then
  ok "Web app        http://127.0.0.1:8080 (was already running)"
elif [ -n "$(port_pids 8080)" ]; then
  fail "Port 8080 is taken but nothing answers. Run scripts/demo-stop.sh, then this script again"
elif [ ! -f mobile/build/web/index.html ]; then
  fail "No web build in mobile/build/web. Build it once: cd mobile && flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000"
elif ! command -v python >/dev/null 2>&1; then
  fail "python not found (needed to serve the web build)"
else
  : >"$LOG_DIR/web.log"; : >"$LOG_DIR/web.err.log"
  start_hidden web "$ROOT/mobile/build/web" python -m http.server 8080 --bind 127.0.0.1
  if wait_http http://127.0.0.1:8080/ 20; then
    ok "Web app        http://127.0.0.1:8080 (build from $(date -r mobile/build/web/main.dart.js '+%d %b %H:%M'))"
  else
    fail "Web server did not start (see .demo/web.err.log)"
  fi
fi

# ---------------------------------------------------------------- 7. phone
step "7/7 Phone (USB)"
if ADB=$(find_adb); then
  devices=$("$ADB" devices 2>/dev/null | tr -d '\r' | awk 'NR > 1 && $2 == "device" { print $1 }')
  unauthorized=$("$ADB" devices 2>/dev/null | tr -d '\r' | awk 'NR > 1 && $2 == "unauthorized" { print $1 }')
  for d in $devices; do
    if "$ADB" -s "$d" reverse tcp:3000 tcp:3000 >/dev/null 2>&1; then
      ok "Phone $d: adb reverse tcp:3000 tcp:3000"
    else
      fail "Phone $d: adb reverse failed (unplug, plug in again, run this script again)"
    fi
  done
  for d in $unauthorized; do
    warn "Phone $d is not authorized: unlock it, tap 'Allow USB debugging', run this script again"
  done
  [ -z "$devices$unauthorized" ] && warn "No phone connected (only needed for the phone part; plug it in and run this script again)"
else
  warn "adb not found: phone step skipped"
fi

# ---------------------------------------------------------------- summary
echo
echo "================ SUMMARY ================"
for r in "${READY[@]}";    do echo "  READY   $r"; done
for w in "${WARNINGS[@]}"; do echo "  WARN    $w"; done
for f in "${FAILED[@]}";   do echo "  FAILED  $f"; done
echo "========================================="
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "All started. Open http://127.0.0.1:8080"
  echo "Optional full check: node scripts/check-project.mjs"
  echo "Demo: bash monitoring/scripts/release.sh deploy-bad   (incident after ~3-5 min)"
  exit 0
fi
echo "${#FAILED[@]} item(s) failed. Fix them and run this script again (it is safe to repeat)."
exit 1
