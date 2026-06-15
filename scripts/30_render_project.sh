#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

DEPLOY_DIR="${DEPLOY_DIR:-/opt/lobehub}"
log "Rendering LobeHub files into $DEPLOY_DIR"

mkdir -p "$DEPLOY_DIR/backup"

install_template "$PROJECT_ROOT/templates/docker-compose.yml" "$DEPLOY_DIR/docker-compose.yml" 0644
install_template "$PROJECT_ROOT/templates/bucket.config.json" "$DEPLOY_DIR/bucket.config.json" 0644
install_template "$PROJECT_ROOT/templates/searxng-settings.yml" "$DEPLOY_DIR/searxng-settings.yml" 0644
install_template "$PROJECT_ROOT/.env.example" "$DEPLOY_DIR/.env.example" 0644

if [[ ! -f "$DEPLOY_DIR/.env" ]]; then
  install_template "$PROJECT_ROOT/.env" "$DEPLOY_DIR/.env" 0600
  log "Copied filled .env into $DEPLOY_DIR/.env"
else
  chmod 0600 "$DEPLOY_DIR/.env"
  log "Preserved existing $DEPLOY_DIR/.env"
fi

install_template "$PROJECT_ROOT/backup.sh" "$DEPLOY_DIR/backup/lobehub_backup.sh" 0755
install_template "$PROJECT_ROOT/scripts/lib.sh" "$DEPLOY_DIR/scripts/lib.sh" 0644
install_template "$PROJECT_ROOT/scripts/70_verify_network.sh" "$DEPLOY_DIR/scripts/healthcheck.sh" 0755

log "Project files rendered"
