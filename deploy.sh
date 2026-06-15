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
  bash deploy.sh security-scan

Commands:
  fresh          Install base packages, Docker, render LobeHub, start services, install backup cron.
  repair         Re-render LobeHub files, restart services, refresh backup cron, and verify.
  verify         Read-only local checks.
  backup         Run PostgreSQL and RustFS backups.
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
