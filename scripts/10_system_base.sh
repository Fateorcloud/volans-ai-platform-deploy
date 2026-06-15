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
  ufw cron logrotate openssl

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

sysctl --system

ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT:-29222}/tcp" comment 'SSH custom port' || true
ufw --force enable

log "Base system setup complete"
