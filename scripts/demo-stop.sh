#!/usr/bin/env bash
# Stops the local demo so the next demo works (Windows, Git Bash).
#
#   bash scripts/demo-stop.sh           normal stop (takes ~6-15 min)
#   bash scripts/demo-stop.sh --force   skip the waits (the next alert may then be held up to 4 h)
#
# 1. release.sh reset: sample-app back to v1, replicas removed (backend still up, so v1 is recorded)
# 2. waits until Alertmanager has no active alerts (up to 15 min)
# 3. waits for the "resolved" notification to n8n (up to 6 min). Stopping before
#    it is sent makes Alertmanager hold the next identical alert for 4 h.
# 4. stops the backend (:3000) and the web server (:8080)
# 5. stops the monitoring stack + executor, then n8n (docker compose stop: data is kept)
#
# Safe to run again: anything already stopped is skipped. If an alert is still
# active after 15 min, NOTHING is stopped; run this script again later.
# Wait times can be changed with DEMO_ALERT_WAIT_SECONDS and DEMO_RESOLVE_WAIT_SECONDS.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FORCE=0
case "${1:-}" in
  --force) FORCE=1 ;;
  "") ;;
  *) sed -n '4,5p' "$0"; exit 2 ;;
esac
ALERT_WAIT=${DEMO_ALERT_WAIT_SECONDS:-900}
RESOLVE_WAIT=${DEMO_RESOLVE_WAIT_SECONDS:-360}
AM=http://127.0.0.1:9093

FAILED=()
step() { echo; echo "== $1"; }
fail() { FAILED+=("$1"); echo "  FAIL  $1"; }

port_pids() {
  netstat -ano 2>/dev/null | tr -d '\r' \
    | awk -v p=":$1" '$1 == "TCP" && $4 == "LISTENING" && substr($2, length($2) - length(p) + 1) == p { print $5 }' \
    | sort -u
}

# stop_port PORT NAME EXPECTED_EXE: kills the process tree listening on PORT,
# but only if it is EXPECTED_EXE (never some other program)
stop_port() {
  local port=$1 name=$2 exe=$3 pids pid image
  pids=$(port_pids "$port")
  if [ -z "$pids" ]; then echo "  $name: not running"; return 0; fi
  for pid in $pids; do
    [ "$pid" = "0" ] && continue
    image=$(tasklist //FI "PID eq $pid" //FO CSV //NH 2>/dev/null | tr -d '\r' | head -n 1 | cut -d, -f1 | tr -d '"')
    if [ "${image,,}" != "$exe" ]; then
      fail "$name: port $port is used by '$image' (PID $pid), not $exe. Left running"
      continue
    fi
    if taskkill //PID "$pid" //T //F >/dev/null 2>&1; then
      echo "  $name: stopped (PID $pid)"
    else
      fail "$name: could not stop PID $pid"
    fi
  done
}

active_alerts() {  # number of active alerts, or "?" when Alertmanager does not answer
  curl -fsS --max-time 5 "$AM/api/v2/alerts?active=true&silenced=false&inhibited=false" 2>/dev/null \
    | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const a=JSON.parse(s);console.log(a.length);for(const x of a)console.error('        firing: '+x.labels.alertname+' '+(x.labels.service||''))}catch{console.log('?')}})"
}

webhook_sent() {  # successful webhook notifications so far (total - failed)
  curl -fsS --max-time 5 "$AM/metrics" 2>/dev/null | tr -d '\r' | awk '
    /^alertmanager_notifications_total\{/        && /integration="webhook"/ { t += $NF }
    /^alertmanager_notifications_failed_total\{/ && /integration="webhook"/ { f += $NF }
    END { printf "%d\n", t - f }'
}

DOCKER_OK=0
docker info >/dev/null 2>&1 && DOCKER_OK=1
AM_UP=0
[ $DOCKER_OK -eq 1 ] && curl -fsS -o /dev/null --max-time 3 "$AM/-/ready" 2>/dev/null && AM_UP=1

# ---------------------------------------------------------------- 1. reset
step "1/5 release.sh reset"
if [ $AM_UP -eq 1 ]; then
  if bash monitoring/scripts/release.sh reset; then
    echo "  sample-app back on v1"
  else
    fail "release.sh reset failed"
  fi
elif [ $DOCKER_OK -eq 0 ]; then
  echo "  Docker is not running: skipped (nothing to reset)"
else
  echo "  monitoring stack is not running: skipped (demo-start.sh starts sample-app on v1)"
fi

# ---------------------------------------------------------------- 2. alerts clear
step "2/5 Waiting until Alertmanager has no active alerts"
if [ $AM_UP -eq 0 ]; then
  echo "  skipped (Alertmanager not running)"
  step "3/5 Resolved notification"; echo "  skipped (Alertmanager not running)"
elif [ $FORCE -eq 1 ]; then
  echo "  skipped (--force)"
  step "3/5 Resolved notification"; echo "  skipped (--force: the next identical alert may be held up to 4 h)"
else
  baseline=$(webhook_sent)
  start=$SECONDS
  while :; do
    n=$(active_alerts)
    if [ "$n" = "0" ]; then echo "  no active alerts"; break; fi
    if [ $((SECONDS - start)) -ge "$ALERT_WAIT" ]; then
      echo
      echo "STOPPED NOTHING: alert(s) still active after $((ALERT_WAIT / 60)) min."
      echo "  Check: bash monitoring/scripts/release.sh status   (all must be version=v1)"
      echo "  Then run this script again. Everything is still running."
      exit 1
    fi
    echo "  $n active alert(s), $(( (SECONDS - start) / 60 )) min waited (normal: ~5-7 min after reset)..."
    sleep 30
  done

  # ------------------------------------------------------------ 3. resolved notification
  step "3/5 Waiting for the resolved notification to n8n (up to $((RESOLVE_WAIT / 60)) min)"
  start=$SECONDS
  while :; do
    now=$(webhook_sent)
    if [ "$now" -gt "$baseline" ]; then echo "  resolved notification sent"; break; fi
    if [ $((SECONDS - start)) -ge "$RESOLVE_WAIT" ]; then
      echo "  no new notification in $((RESOLVE_WAIT / 60)) min (fine if no alert fired since the last stop)"
      break
    fi
    echo "  waiting... $(( (SECONDS - start) / 60 )) min"
    sleep 30
  done
fi

# ---------------------------------------------------------------- 4. backend + web
step "4/5 Backend and web server"
stop_port 3000 "Backend (:3000)" node.exe
stop_port 8080 "Web server (:8080)" python.exe

# ---------------------------------------------------------------- 5. containers
step "5/5 Monitoring + executor, n8n"
if [ $DOCKER_OK -eq 1 ]; then
  if (cd monitoring && docker compose stop) >/dev/null 2>&1; then
    echo "  monitoring stack + executor: stopped"
  else
    fail "monitoring stack: docker compose stop failed (cd monitoring && docker compose stop)"
  fi
  if (cd automation && docker compose -p ccdemo stop) >/dev/null 2>&1; then
    echo "  n8n: stopped"
  else
    fail "n8n: docker compose stop failed (cd automation && docker compose -p ccdemo stop)"
  fi
else
  echo "  Docker is not running: nothing to stop"
fi

echo
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "All stopped. You can now quit Docker Desktop. Next demo: bash scripts/demo-start.sh"
  exit 0
fi
echo "Done with ${#FAILED[@]} problem(s):"
for f in "${FAILED[@]}"; do echo "  - $f"; done
exit 1
