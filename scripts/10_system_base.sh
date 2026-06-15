#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

log "Installing base packages"
apt update
apt -y upgrade
apt install -y \
  curl wget git vim nano htop unzip jq ca-certificates gnupg lsb-release \
  ufw fail2ban cron logrotate openssl autossh privoxy

if ! swapon --show | grep -q '^/swapfile'; then
  log "Creating 2G swapfile"
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

cat >/etc/sysctl.d/97-swap.conf <<'EOF2'
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF2

cat >/etc/sysctl.d/99-network-tuning.conf <<'EOF2'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
EOF2

sysctl --system

ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT:-29222}/tcp" comment 'SSH custom port' || true
ufw allow 80/tcp comment 'HTTP for Caddy image site and ACME' || true
ufw allow 443/tcp comment 'HTTPS for Caddy image site' || true
if [[ "${ENABLE_XUI:-true}" == "true" ]]; then
  ufw allow "${XUI_REALITY_PORT:-31444}/tcp" comment '3xui Reality inbound' || true
fi
ufw --force enable

log "Base system setup complete"
