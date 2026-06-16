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
  sudo bash deploy.sh verify
  sudo bash deploy.sh backup
  sudo bash deploy.sh xui [--yes]
  sudo bash deploy.sh nat-proxy [--yes]
  sudo bash deploy.sh network [--yes]
  bash deploy.sh security-scan

Commands:
  fresh          Install base packages, Docker, render LobeHub, start services, install backup cron.
  repair         Re-render LobeHub files, restart services, refresh backup cron, and verify.
  verify         Read-only local checks.
  backup         Run PostgreSQL and RustFS backups.
  xui            Install or repair the optional xui side component.
  nat-proxy      Install or repair the optional NAT egress proxy.
  network        Run xui and nat-proxy setup in sequence.
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
    confirm "Run fresh LobeHub deployment on this server?"
    bash "$PROJECT_DIR/scripts/00_preflight.sh"
    bash "$PROJECT_DIR/scripts/10_system_base.sh"
    bash "$PROJECT_DIR/scripts/20_install_docker.sh"
    bash "$PROJECT_DIR/scripts/30_render_project.sh"
    bash "$PROJECT_DIR/scripts/40_start_services.sh"
    bash "$PROJECT_DIR/scripts/60_setup_backup.sh"
    bash "$PROJECT_DIR/scripts/70_verify_network.sh"
    ;;
  repair)
    require_root
    load_env
    confirm "Repair LobeHub files, backup cron, and services?"
    bash "$PROJECT_DIR/scripts/00_preflight.sh"
    bash "$PROJECT_DIR/scripts/30_render_project.sh"
    bash "$PROJECT_DIR/scripts/40_start_services.sh"
    bash "$PROJECT_DIR/scripts/60_setup_backup.sh"
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
  xui)
    require_root
    load_env
    confirm "Set up optional xui component?"
    bash "$PROJECT_DIR/scripts/35_setup_xui.sh"
    ;;
  nat-proxy)
    require_root
    load_env
    confirm "Set up optional NAT egress proxy?"
    bash "$PROJECT_DIR/scripts/50_setup_nat_proxy.sh"
    ;;
  network)
    require_root
    load_env
    confirm "Set up optional xui and NAT network components?"
    bash "$PROJECT_DIR/scripts/35_setup_xui.sh"
    bash "$PROJECT_DIR/scripts/50_setup_nat_proxy.sh"
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
