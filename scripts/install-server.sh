#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# AI Platform server bootstrap
#
# Fresh Ubuntu 22.04/24.04 one-shot installer.
# Run as root from a cloned or uploaded copy of this repository.
# -----------------------------------------------------------------------------
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_TARGET="${INSTALL_TARGET:-/opt/Serve}"
SSH_PORT="${SSH_PORT:-29222}"
ENABLE_UFW="${ENABLE_UFW:-true}"

log() { echo -e "\033[1;36m[install]\033[0m $*"; }
warn() { echo -e "\033[1;33m[warn]\033[0m $*" >&2; }
die()  { echo -e "\033[1;31m[err]\033[0m $*" >&2; exit 1; }

need_root() {
  if [[ $EUID -ne 0 ]]; then
    die "Run as root. This script writes /opt, /etc/systemd, /etc/cron.d, and firewall rules."
  fi
}

install_packages() {
  log "installing base packages"
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release rsync ufw
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "docker + compose already installed: $(docker --version)"
    return
  fi

  log "installing Docker Engine + compose plugin"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  log "docker installed: $(docker --version)"
}

place_repo() {
  if [[ "$REPO_DIR" != "$INSTALL_TARGET" ]]; then
    log "mirroring repo to $INSTALL_TARGET"
    mkdir -p "$INSTALL_TARGET"
    rsync -a \
      --exclude '.git' \
      --exclude '.env' \
      --exclude '.env.*' \
      --exclude 'pg_data' \
      --exclude 'newapi_data' \
      --exclude 'open-webui_data' \
      --exclude 'caddy_data' \
      --exclude 'caddy_config' \
      --exclude 'caddy_logs' \
      --exclude 'server-backups' \
      --exclude 'clash-work' \
      "$REPO_DIR"/ "$INSTALL_TARGET"/
  fi

  chmod +x "$INSTALL_TARGET"/scripts/*.sh "$INSTALL_TARGET"/backup/*.sh "$INSTALL_TARGET"/systemd/*.sh 2>/dev/null || true
}

install_proxy_firewall() {
  local unit_src="$INSTALL_TARGET/systemd/ai-proxy-firewall.service"
  local unit_dst="/etc/systemd/system/ai-proxy-firewall.service"

  if [[ -f "$unit_src" ]]; then
    cp "$unit_src" "$unit_dst"
    systemctl daemon-reload
    systemctl enable ai-proxy-firewall.service
    log "installed ai-proxy-firewall.service"
  else
    warn "missing $unit_src; skip proxy firewall service"
  fi
}

install_health_cron() {
  local hc="$INSTALL_TARGET/systemd/proxy-healthcheck.sh"
  local cron_file="/etc/cron.d/proxy-healthcheck"

  if [[ ! -x "$hc" ]]; then
    warn "missing executable $hc; skip proxy health cron"
    return
  fi

  cat > "$cron_file" <<EOF
# Host proxy liveness check for AI Platform containers.
* * * * * root ${hc} >> /var/log/proxy-health.log 2>&1
EOF
  chmod 644 "$cron_file"
  log "installed $cron_file"
}

install_backup_cron() {
  local bk="$INSTALL_TARGET/backup/pg_dump.sh"
  local cron_file="/etc/cron.d/pg-daily-backup"

  if [[ ! -x "$bk" ]]; then
    warn "missing executable $bk; skip postgres backup cron"
    return
  fi

  cat > "$cron_file" <<EOF
# Daily PostgreSQL logical backup at 03:00 Asia/Shanghai.
CRON_TZ=Asia/Shanghai
STACK_DIR=$INSTALL_TARGET
0 3 * * * root ${bk} >> /var/log/pgdump.log 2>&1
EOF
  chmod 644 "$cron_file"
  log "installed $cron_file"
}

setup_firewall() {
  if [[ "$ENABLE_UFW" != "true" ]]; then
    warn "ENABLE_UFW is not true; skip ufw setup"
    return
  fi

  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${SSH_PORT}/tcp" comment "SSH custom port"
  ufw allow 80/tcp comment "HTTP for optional Caddy image site and ACME"
  ufw allow 443/tcp comment "HTTPS for optional Caddy image site"
  log "ufw rules prepared; enabling ufw"
  ufw --force enable
}

ensure_env_file() {
  if [[ ! -f "$INSTALL_TARGET/.env" ]]; then
    cp "$INSTALL_TARGET/.env.example" "$INSTALL_TARGET/.env"
    chmod 600 "$INSTALL_TARGET/.env"
    warn "created $INSTALL_TARGET/.env from template; edit secrets before starting compose"
  fi
}

print_next_steps() {
  cat <<EOF

Next steps:
  cd $INSTALL_TARGET
  nano .env
  docker compose config --quiet
  docker compose up -d postgres newapi

After NewAPI token is created:
  docker compose up -d open-webui cloudflared

Optional image site:
  docker compose -f docker-compose.yml -f docker-compose.image.yml --profile image config --quiet
  docker compose -f docker-compose.yml -f docker-compose.image.yml --profile image up -d

If a host proxy is listening on the Docker gateway:
  systemctl start ai-proxy-firewall.service
EOF
}

main() {
  need_root
  log "install target:  $INSTALL_TARGET"
  log "source repo dir: $REPO_DIR"
  install_packages
  install_docker
  place_repo
  install_proxy_firewall
  install_health_cron
  install_backup_cron
  setup_firewall
  ensure_env_file
  print_next_steps
}

main "$@"
