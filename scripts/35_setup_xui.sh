#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

if [[ "${ENABLE_XUI:-true}" != "true" ]]; then
  log "ENABLE_XUI is not true; skipping 3xui setup"
  docker network inspect xui_default >/dev/null 2>&1 || docker network create xui_default >/dev/null
  exit 0
fi

require_env_not_placeholder XUI_ADMIN_USERNAME
require_env_not_placeholder XUI_ADMIN_PASSWORD

XUI_DEPLOY_DIR="${XUI_DEPLOY_DIR:-/opt/Serve/xui}"
log "Rendering and starting 3xui in $XUI_DEPLOY_DIR"

mkdir -p "$XUI_DEPLOY_DIR"
install_template "$PROJECT_ROOT/templates/xui-docker-compose.yml" "$XUI_DEPLOY_DIR/docker-compose.yml" 0644
install_template "$PROJECT_ROOT/.env" "$XUI_DEPLOY_DIR/.env" 0600

(cd "$XUI_DEPLOY_DIR" && docker compose up -d)

for _ in $(seq 1 30); do
  if docker exec xui-3xui /app/x-ui setting -show >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

docker exec xui-3xui /app/x-ui setting \
  -username "$XUI_ADMIN_USERNAME" \
  -password "$XUI_ADMIN_PASSWORD" \
  -port "${XUI_PANEL_PORT:-12053}" \
  -webBasePath "/" \
  -listenIP "0.0.0.0"

(cd "$XUI_DEPLOY_DIR" && docker compose restart xui)

log "3xui container is running. Configure Reality inbound and nat-ai routing in the panel."
