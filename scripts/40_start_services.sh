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
docker compose ps
