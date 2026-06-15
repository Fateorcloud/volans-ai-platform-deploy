#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

DEPLOY_DIR="${DEPLOY_DIR:-/opt/Serve}"
cd "$DEPLOY_DIR"

log "Validating Compose config"
docker compose config --quiet

log "Starting services"
docker compose up -d
docker compose ps

systemctl restart fail2ban || warn "fail2ban restart failed; check jail configuration"
