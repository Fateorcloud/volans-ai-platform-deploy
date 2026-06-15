#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() {
  printf '[lobehub-deploy] %s\n' "$*"
}

warn() {
  printf '[lobehub-deploy][WARN] %s\n' "$*" >&2
}

die() {
  printf '[lobehub-deploy][ERROR] %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run as root, for example: sudo bash deploy.sh verify"
  fi
}

confirm() {
  local prompt="$1"
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    log "$prompt -- yes"
    return 0
  fi
  read -r -p "$prompt [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) die "Cancelled by user" ;;
  esac
}

load_env() {
  local env_file="${ENV_FILE:-$PROJECT_ROOT/.env}"
  if [[ ! -f "$env_file" ]]; then
    die "Missing .env. Copy .env.example to .env and fill placeholders."
  fi
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

require_env_present() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    die "Missing required env var: $name"
  fi
}

require_env_not_placeholder() {
  local name="$1"
  local value="${!name:-}"
  require_env_present "$name"
  if [[ "$value" == CHANGE_ME* || "$value" == *CHANGE_ME* ]]; then
    die "Env var still uses placeholder: $name"
  fi
}

install_template() {
  local src="$1"
  local dst="$2"
  local mode="${3:-0644}"
  install -D -m "$mode" "$src" "$dst"
}
