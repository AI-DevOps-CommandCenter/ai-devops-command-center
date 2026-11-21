#!/usr/bin/env bash
# =============================================================================
# Local database test runner. LOCAL ONLY: never connects to a remote database.
#
# Mode 1 (default): throwaway PostgreSQL cluster
#   Needs PostgreSQL server binaries (initdb, pg_ctl, psql). Creates a temporary
#   cluster on 127.0.0.1:${TEST_PG_PORT:-55441}, applies the Supabase shim,
#   the baseline, the synthetic seed and the remaining migrations, checks data
#   preservation, runs all SQL tests and a rollback round-trip, then deletes
#   the cluster.
#
# Mode 2: local Supabase stack (after `npx supabase db reset`)
#   DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
#     bash database/tests/run-local-db-tests.sh
#   Runs the SQL tests only. DB_URL must point to 127.0.0.1/localhost.
#
# Options (environment variables):
#   PG_BIN        directory with PostgreSQL binaries (auto-detected)
#   TEST_PG_PORT  port for the throwaway cluster (default 55432)
#   KEEP_CLUSTER  1 = keep the cluster running after the tests (debugging)
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATIONS_DIR="$ROOT/supabase/migrations"
ROLLBACK_DIR="$ROOT/database/rollback"
TESTS_DIR="$ROOT/database/tests/sql"
HARNESS_DIR="$ROOT/database/tests/harness"
SEED_FILE="$ROOT/supabase/seed.sql"

failures=0
passed_assertions=0
declare -a results=()

log() { printf '%s\n' "$*"; }
fail() { log "FAIL: $*"; failures=$((failures + 1)); }

find_pg_bin() {
  if [[ -n "${PG_BIN:-}" ]]; then printf '%s' "$PG_BIN"; return; fi
  if command -v initdb >/dev/null 2>&1; then dirname "$(command -v initdb)"; return; fi
  local candidate
  for candidate in "/c/Program Files/PostgreSQL"/*/bin /usr/lib/postgresql/*/bin /opt/homebrew/opt/postgresql@*/bin; do
    if [[ -x "$candidate/initdb" || -x "$candidate/initdb.exe" ]]; then printf '%s' "$candidate"; return; fi
  done
}

PG_BIN_DIR="$(find_pg_bin)"
if [[ -z "$PG_BIN_DIR" ]]; then
  log "PostgreSQL binaries not found. Install PostgreSQL 17+ or set PG_BIN."
  exit 2
fi
PSQL_BIN="$PG_BIN_DIR/psql"

if [[ -n "${DB_URL:-}" ]]; then
  MODE="supabase-local"
  if [[ ! "$DB_URL" =~ @(127\.0\.0\.1|localhost)(:[0-9]+)?/ ]]; then
    log "Refusing to run: DB_URL must point to 127.0.0.1 or localhost (local stack only)."
    exit 2
  fi
  CONN=("$DB_URL")
else
  MODE="throwaway-cluster"
  PORT="${TEST_PG_PORT:-55441}"
  WORK_DIR="$(mktemp -d)"
  DATA_DIR="$WORK_DIR/data"
  DB_NAME="devops_test"
  CONN=(-h 127.0.0.1 -p "$PORT" -U postgres -d "$DB_NAME")

  cleanup() {
    if [[ "${KEEP_CLUSTER:-0}" == "1" ]]; then
      log "Cluster kept running: port $PORT, data $DATA_DIR"
      return
    fi
    timeout 60 "$PG_BIN_DIR/pg_ctl" -D "$DATA_DIR" -m fast -w stop >/dev/null 2>&1
    # Windows may keep files locked briefly after shutdown: retry the removal.
    local attempt
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
      rm -rf "$WORK_DIR" 2>/dev/null && [[ ! -e "$WORK_DIR" ]] && return
      sleep 1
    done
    log "Note: could not remove temporary folder $WORK_DIR (locked); delete it manually."
  }
  trap cleanup EXIT
fi

psql_run() {
  "$PSQL_BIN" -X -q -v ON_ERROR_STOP=1 "${CONN[@]}" "$@"
}

step() {
  local label="$1"; shift
  local output
  if output="$("$@" 2>&1)"; then
    log "  [ok]   $label"
    return 0
  fi
  log "  [FAIL] $label"
  printf '%s\n' "$output" | grep -v -E 'NOTICE:  ok - ' | tail -n 20 | sed 's/^/         /'
  failures=$((failures + 1))
  return 1
}

apply_file() { psql_run -f "$1"; }

log "Database tests: mode=$MODE, PostgreSQL=$("$PSQL_BIN" --version | awk '{print $3}')"

mapfile -t MIGRATIONS < <(ls "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort)
if [[ ${#MIGRATIONS[@]} -eq 0 ]]; then
  log "No migrations found in $MIGRATIONS_DIR"
  exit 2
fi
BASELINE="${MIGRATIONS[0]}"

if [[ "$MODE" == "throwaway-cluster" ]]; then
  log "Setup:"
  step "initdb (temporary cluster)" "$PG_BIN_DIR/initdb" -D "$DATA_DIR" -U postgres -A trust -E UTF8 --no-locale || exit 1
  # pg_ctl's output must NOT go to a pipe: the server inherits the handle and
  # the pipe would never close (hangs on Windows). Send it to /dev/null.
  if timeout 90 "$PG_BIN_DIR/pg_ctl" -D "$DATA_DIR" -l "$WORK_DIR/postgres.log" \
      -o "-p $PORT -c listen_addresses=127.0.0.1" -w -t 60 start >/dev/null 2>&1; then
    log "  [ok]   start PostgreSQL on 127.0.0.1:$PORT"
  else
    log "  [FAIL] start PostgreSQL on 127.0.0.1:$PORT (see server log below)"
    tail -n 10 "$WORK_DIR/postgres.log" 2>/dev/null | sed 's/^/         /'
    exit 1
  fi
  step "create database $DB_NAME" "$PSQL_BIN" -X -q -h 127.0.0.1 -p "$PORT" -U postgres -d postgres \
    -c "CREATE DATABASE $DB_NAME" || exit 1
  step "Supabase compatibility shim" apply_file "$HARNESS_DIR/supabase_shim.sql" || exit 1
  step "migration $(basename "$BASELINE")" apply_file "$BASELINE" || exit 1
  step "synthetic seed (supabase/seed.sql)" apply_file "$SEED_FILE" || exit 1
  step "data snapshot after baseline + seed" psql_run -v mode=snapshot -f "$HARNESS_DIR/data_snapshot.sql" || exit 1
  for migration in "${MIGRATIONS[@]:1}"; do
    step "migration $(basename "$migration")" apply_file "$migration" || exit 1
  done
  step "data preserved by later migrations" psql_run -v mode=verify -f "$HARNESS_DIR/data_snapshot.sql"
fi

log "Tests:"
step "test helpers" apply_file "$HARNESS_DIR/test_helpers.sql" || exit 1

for test_file in "$TESTS_DIR"/*.sql; do
  name="$(basename "$test_file")"
  output="$(psql_run -f "$test_file" 2>&1)"
  status=$?
  oks="$(printf '%s\n' "$output" | grep -c 'NOTICE:  ok - ')"
  passed_assertions=$((passed_assertions + oks))
  if [[ $status -eq 0 ]]; then
    log "  [ok]   $name ($oks assertions)"
    results+=("PASS $name $oks")
  else
    log "  [FAIL] $name ($oks assertions passed before the failure)"
    printf '%s\n' "$output" | grep -E 'ERROR|not ok' | head -n 5 | sed 's/^/         /'
    results+=("FAIL $name $oks")
    failures=$((failures + 1))
  fi
done

if [[ "$MODE" == "throwaway-cluster" ]]; then
  log "Rollback round-trip:"
  for (( i=${#MIGRATIONS[@]}-1; i>=1; i-- )); do
    migration="${MIGRATIONS[$i]}"
    down="$ROLLBACK_DIR/$(basename "${migration%.sql}").down.sql"
    if [[ ! -f "$down" ]]; then
      fail "no rollback script for $(basename "$migration")"
      continue
    fi
    step "rollback $(basename "$down")" apply_file "$down"
  done
  step "baseline structure restored after rollback" apply_file "$HARNESS_DIR/check_baseline_only.sql"
  step "data preserved after rollback" psql_run -v mode=verify -f "$HARNESS_DIR/data_snapshot.sql"
  for migration in "${MIGRATIONS[@]:1}"; do
    step "re-apply $(basename "$migration")" apply_file "$migration"
  done
  step "data preserved after re-apply" psql_run -v mode=verify -f "$HARNESS_DIR/data_snapshot.sql"

  # Rollback safety: a rollback must refuse to drop tables that contain data.
  guard_down="$ROLLBACK_DIR/20261107000200_create_target_tables.down.sql"
  if [[ -f "$guard_down" ]]; then
    psql_run -c "INSERT INTO public.automation_runs (workflow_name) VALUES ('rollback-guard-probe')" >/dev/null 2>&1
    if psql_run -f "$guard_down" >/dev/null 2>&1; then
      fail "rollback guard: target tables were dropped although they contained data"
    else
      log "  [ok]   rollback refuses to drop target tables that contain data"
    fi
    psql_run -c "DELETE FROM public.automation_runs WHERE workflow_name = 'rollback-guard-probe'" >/dev/null 2>&1
  fi

  # Rollback safety for the A2-A7 migrations (probe data, then clean up).
  guard_700="$ROLLBACK_DIR/20261107000700_approval_workflow.down.sql"
  if [[ -f "$guard_700" ]]; then
    psql_run -c "UPDATE public.approvals SET decision_reason = 'rollback-guard-probe' WHERE id = 'f1000000-0000-4000-8000-000000000001'" >/dev/null 2>&1
    if psql_run -f "$guard_700" >/dev/null 2>&1; then
      fail "rollback guard: approval workflow columns were dropped although they contained data"
    else
      log "  [ok]   rollback refuses to drop approval workflow columns that contain data"
    fi
    psql_run -c "UPDATE public.approvals SET decision_reason = NULL WHERE id = 'f1000000-0000-4000-8000-000000000001'" >/dev/null 2>&1
  fi

  guard_400="$ROLLBACK_DIR/20261107000400_automation_identity.down.sql"
  if [[ -f "$guard_400" ]]; then
    psql_run -c "INSERT INTO auth.users (id, email) VALUES ('a9999999-0000-4000-8000-000000000001', 'rollback.probe@example.test'); UPDATE public.profiles SET role = 'automation' WHERE id = 'a9999999-0000-4000-8000-000000000001'" >/dev/null 2>&1
    if psql_run -f "$guard_400" >/dev/null 2>&1; then
      fail "rollback guard: automation role removed while an automation identity exists"
    else
      log "  [ok]   rollback refuses to remove the automation role while it is in use"
    fi
    psql_run -c "DELETE FROM auth.users WHERE id = 'a9999999-0000-4000-8000-000000000001'" >/dev/null 2>&1
  fi
  step "data preserved after rollback guard probes" psql_run -v mode=verify -f "$HARNESS_DIR/data_snapshot.sql"
fi

log ""
log "Summary: ${#results[@]} test files, $passed_assertions assertions passed, $failures failure(s)."
[[ $failures -eq 0 ]]
