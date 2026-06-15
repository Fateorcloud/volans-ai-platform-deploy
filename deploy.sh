#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$PROJECT_DIR/scripts/lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  sudo bash deploy.sh fresh [--yes]
  sudo bash deploy.sh repair [--yes]
  sudo bash deploy.sh proxy [--yes]
  sudo bash deploy.sh verify
  sudo bash deploy.sh backup
  bash deploy.sh security-scan

Commands:
  fresh   Install base packages, Docker, render project, start services, setup proxy and backup.
  repair  Re-render project, repair proxy/firewall/backup, and verify.
  proxy   Install or repair NAT VPS egress proxy only.
  verify  Read-only checks.
  backup  Run PostgreSQL backup.
  security-scan  Check for common secrets before publishing.
USAGE
}

COMMAND="${1:-help}"
if [[ "${2:-}" == "--yes" || "${1:-}" == "--yes" ]]; then
  export ASSUME_YES=1
fi

case "$COMMAND" in
  fresh)
    require_root
    load_env
    confirm "Run fresh deployment on this server?"
    bash "$PROJECT_DIR/scripts/00_preflight.sh"
    bash "$PROJECT_DIR/scripts/10_system_base.sh"
    bash "$PROJECT_DIR/scripts/20_install_docker.sh"
    bash "$PROJECT_DIR/scripts/30_render_project.sh"
    bash "$PROJECT_DIR/scripts/35_setup_xui.sh"
    bash "$PROJECT_DIR/scripts/40_start_services.sh"
    if [[ "${ENABLE_NAT_PROXY:-true}" == "true" ]]; then
      bash "$PROJECT_DIR/scripts/50_setup_nat_proxy.sh"
    fi
    bash "$PROJECT_DIR/scripts/60_setup_backup.sh"
    bash "$PROJECT_DIR/scripts/70_verify_network.sh"
    ;;
  repair)
    require_root
    load_env
    confirm "Repair project files, proxy, backup, and verify?"
    bash "$PROJECT_DIR/scripts/00_preflight.sh"
    bash "$PROJECT_DIR/scripts/30_render_project.sh"
    bash "$PROJECT_DIR/scripts/35_setup_xui.sh"
    bash "$PROJECT_DIR/scripts/40_start_services.sh"
    if [[ "${ENABLE_NAT_PROXY:-true}" == "true" ]]; then
      bash "$PROJECT_DIR/scripts/50_setup_nat_proxy.sh"
    fi
    bash "$PROJECT_DIR/scripts/60_setup_backup.sh"
    bash "$PROJECT_DIR/scripts/70_verify_network.sh"
    ;;
  proxy)
    require_root
    load_env
    confirm "Install or repair NAT VPS egress proxy?"
    bash "$PROJECT_DIR/scripts/50_setup_nat_proxy.sh"
    bash "$PROJECT_DIR/scripts/70_verify_network.sh"
    ;;
  verify)
    require_root
    bash "$PROJECT_DIR/scripts/70_verify_network.sh"
    ;;
  backup)
    require_root
    bash "$PROJECT_DIR/backup.sh"
    ;;
  security-scan)
    bash "$PROJECT_DIR/scripts/80_security_scan.sh"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
