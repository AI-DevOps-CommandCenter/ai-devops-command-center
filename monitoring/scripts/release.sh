#!/usr/bin/env bash
# sample-app releases, for the rollback and scale playbooks.
#
#   scripts/release.sh build        build dc-sample-app:stable (v1) and :v2-bad
#   scripts/release.sh deploy-bad   deploy v2-bad: 50% errors from startup (a restart does not fix it)
#   scripts/release.sh reset        back to the compose image, remove executor replicas
#   scripts/release.sh status       instances, image and version
#
# dc-sample-app:stable is the executor's rollback_image (infrastructure/playbooks/executor/allowlist.json).
set -euo pipefail
export MSYS_NO_PATHCONV=1  # Git Bash on Windows
cd "$(dirname "$0")/.."

REPLICA_LABEL="dc.executor.replica-of=sample-app"

usage() {
  sed -n '4,7p' "$0"
  exit 2
}

build() {
  docker build -q -t dc-sample-app:stable --build-arg APP_VERSION=v1 sample-app >/dev/null
  docker build -q -t dc-sample-app:v2-bad --build-arg APP_VERSION=v2 --build-arg RELEASE_FAULT=errors:0.5 sample-app >/dev/null
  echo "built dc-sample-app:stable (v1) and dc-sample-app:v2-bad (v2, RELEASE_FAULT=errors:0.5)"
}

ensure_built() {
  docker image inspect dc-sample-app:stable dc-sample-app:v2-bad >/dev/null 2>&1 || build
}

remove_replicas() {
  local ids
  ids=$(docker ps -aq --filter "label=$REPLICA_LABEL")
  if [ -n "$ids" ]; then
    # shellcheck disable=SC2086
    docker rm -f $ids >/dev/null
    echo "removed $(echo "$ids" | wc -w | tr -d ' ') replica(s)"
  fi
}

status() {
  local names
  names=$(docker ps -a --filter "name=^dc-sample-app(-[0-9]+)?$" --format '{{.Names}}' | sort)
  for name in $names; do
    local image state version
    image=$(docker inspect -f '{{.Config.Image}}' "$name")
    state=$(docker inspect -f '{{.State.Status}}' "$name")
    version=$(docker exec "$name" python -c "import json,urllib.request;print(json.load(urllib.request.urlopen('http://127.0.0.1:8000/health',timeout=3))['version'])" 2>/dev/null || echo "?")
    printf '%-18s %-22s %-8s version=%s\n' "$name" "$image" "$state" "$version"
  done
}

case "${1:-}" in
  build) build ;;
  deploy-bad)
    ensure_built
    remove_replicas
    SAMPLE_APP_IMAGE=dc-sample-app:v2-bad docker compose up -d --no-build sample-app
    echo "deployed v2-bad. The executor's rollback playbook goes back to dc-sample-app:stable."
    ;;
  reset)
    remove_replicas
    docker compose up -d --force-recreate --no-deps sample-app
    ;;
  status) status ;;
  *) usage ;;
esac
