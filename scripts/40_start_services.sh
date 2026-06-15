#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

DEPLOY_DIR="${DEPLOY_DIR:-/opt/lobehub}"
cd "$DEPLOY_DIR"

log "Validating Compose config"
docker compose config --quiet

log "Starting LobeHub services"
docker compose up -d

log "Waiting for LobeHub HTTP entry"
for _ in $(seq 1 60); do
  if curl -fsS --max-time 5 "http://127.0.0.1:${LOBE_PORT:-3210}/" >/dev/null; then
    break
  fi
  sleep 5
done

docker compose ps
