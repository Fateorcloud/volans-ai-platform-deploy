#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

if [[ "${ENABLE_NAT_PROXY:-false}" != "true" ]]; then
  log "ENABLE_NAT_PROXY is not true; skipping optional NAT proxy setup"
  exit 0
fi

require_env_present NAT_SSH_HOST
require_env_present NAT_SSH_PORT
require_env_present NAT_SSH_USER
require_env_present NAT_SSH_KEY_PATH

if [[ ! -f "$NAT_SSH_KEY_PATH" ]]; then
  warn "NAT SSH key not found: $NAT_SSH_KEY_PATH"
  warn "Generate or copy it manually, then authorize ${NAT_SSH_KEY_PATH}.pub on $NAT_SSH_USER@$NAT_SSH_HOST"
  die "NAT SSH key missing"
fi

apt install -y autossh privoxy

render_nat_socks_service "/etc/systemd/system/nat-socks.service"

if ! grep -q 'LobeHub optional local HTTP proxy' /etc/privoxy/config; then
  cat "$PROJECT_ROOT/templates/privoxy-lobehub.conf" >> /etc/privoxy/config
else
  log "Privoxy optional LobeHub proxy block already present"
fi

systemctl daemon-reload
systemctl enable --now nat-socks
systemctl restart privoxy

log "Optional NAT proxy setup complete"
