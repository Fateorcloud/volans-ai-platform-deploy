#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

DEPLOY_DIR="${DEPLOY_DIR:-/opt/Serve}"
log "Rendering project files into $DEPLOY_DIR"

mkdir -p "$DEPLOY_DIR/backup" "$DEPLOY_DIR/scripts" "$DEPLOY_DIR/systemd" "$DEPLOY_DIR/open-webui_data/patches"

install_template "$PROJECT_ROOT/templates/docker-compose.yml" "$DEPLOY_DIR/docker-compose.yml" 0644
install_template "$PROJECT_ROOT/templates/init.sql" "$DEPLOY_DIR/init.sql" 0644
install_template "$PROJECT_ROOT/templates/Caddyfile.image" "$DEPLOY_DIR/Caddyfile.image" 0644
install_template "$PROJECT_ROOT/templates/patch_safe_web_loader.py" "$DEPLOY_DIR/open-webui_data/patches/patch_safe_web_loader.py" 0644
install_template "$PROJECT_ROOT/templates/99-volans-autofill.sh" "$DEPLOY_DIR/scripts/99-volans-autofill.sh" 0755
install_template "$PROJECT_ROOT/.env.example" "$DEPLOY_DIR/.env.example" 0644

if [[ ! -f "$DEPLOY_DIR/.env" ]]; then
  install_template "$PROJECT_ROOT/.env" "$DEPLOY_DIR/.env" 0600
  log "Copied filled .env into $DEPLOY_DIR/.env"
else
  chmod 0600 "$DEPLOY_DIR/.env"
  log "Preserved existing $DEPLOY_DIR/.env"
fi

install_template "$PROJECT_ROOT/backup.sh" "$DEPLOY_DIR/backup/pg_dump.sh" 0755
install_template "$PROJECT_ROOT/scripts/lib.sh" "$DEPLOY_DIR/scripts/lib.sh" 0644
install_template "$PROJECT_ROOT/scripts/70_verify_network.sh" "$DEPLOY_DIR/scripts/healthcheck.sh" 0755
install_template "$PROJECT_ROOT/templates/ai-proxy-firewall.sh" "/usr/local/sbin/ai-proxy-firewall.sh" 0755
install_template "$PROJECT_ROOT/templates/ai-proxy-firewall.service" "/etc/systemd/system/ai-proxy-firewall.service" 0644
install_template "$PROJECT_ROOT/templates/caddy-basicauth-filter.conf" "/etc/fail2ban/filter.d/caddy-basicauth.conf" 0644
install_template "$PROJECT_ROOT/templates/caddy-basicauth-jail.local" "/etc/fail2ban/jail.d/caddy-basicauth.local" 0644
render_nat_socks_service "/etc/systemd/system/nat-socks.service"

log "Project files rendered"
