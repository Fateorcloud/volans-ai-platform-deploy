#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

if [[ "${ENABLE_NAT_PROXY:-true}" != "true" ]]; then
  log "ENABLE_NAT_PROXY is not true; skipping NAT proxy setup"
  exit 0
fi

require_env_present NAT_SSH_HOST
require_env_present NAT_SSH_PORT
require_env_present NAT_SSH_USER
require_env_present NAT_SSH_KEY_PATH

if [[ ! -f "$NAT_SSH_KEY_PATH" ]]; then
  warn "NAT SSH key not found: $NAT_SSH_KEY_PATH"
  warn "Generate/copy it manually, then run: ssh-copy-id -i ${NAT_SSH_KEY_PATH}.pub -p $NAT_SSH_PORT $NAT_SSH_USER@$NAT_SSH_HOST"
  die "NAT SSH key missing"
fi

apt install -y autossh privoxy

render_nat_socks_service "/etc/systemd/system/nat-socks.service"
install_template "$PROJECT_ROOT/templates/ai-proxy-firewall.sh" "/usr/local/sbin/ai-proxy-firewall.sh" 0755
install_template "$PROJECT_ROOT/templates/ai-proxy-firewall.service" "/etc/systemd/system/ai-proxy-firewall.service" 0644

ensure_privoxy_line() {
  local line="$1"
  grep -Fxq "$line" /etc/privoxy/config || printf '%s\n' "$line" >> /etc/privoxy/config
}

if ! grep -q 'AI platform local HTTP proxy' /etc/privoxy/config; then
  cat "$PROJECT_ROOT/templates/privoxy-ai-platform.conf" >> /etc/privoxy/config
else
  log "Privoxy AI platform block already present; ensuring current listen and forward rules"
  ensure_privoxy_line 'listen-address 172.18.0.1:7890'
  ensure_privoxy_line 'listen-address 172.19.0.1:7890'
  ensure_privoxy_line 'forward-socks5t / 127.0.0.1:10808 .'
fi

systemctl daemon-reload
systemctl enable --now nat-socks
systemctl restart privoxy
systemctl enable --now ai-proxy-firewall
systemctl restart ai-proxy-firewall

log "NAT proxy setup complete"
