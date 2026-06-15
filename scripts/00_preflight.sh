#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

log "Running preflight checks"

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  log "Detected OS: ${PRETTY_NAME:-unknown}"
  [[ "${ID:-}" == "ubuntu" ]] || warn "This project is designed for Ubuntu 22.04 LTS."
else
  warn "/etc/os-release not found"
fi

for name in \
  DB_USER DB_PASS NEWAPI_MASTER_KEY CF_TUNNEL_TOKEN WEBUI_SECRET_KEY \
  OPENWEBUI_ENABLE_SIGNUP OPENWEBUI_DEFAULT_USER_ROLE \
  IMAGE_BASIC_AUTH_HASH CADDY_ACME_EMAIL; do
  require_env_not_placeholder "$name"
done

if [[ "${ENABLE_XUI:-true}" == "true" ]]; then
  for name in XUI_ADMIN_USERNAME XUI_ADMIN_PASSWORD XUI_PANEL_PORT XUI_REALITY_PORT; do
    require_env_not_placeholder "$name"
  done
fi

if [[ "${ENABLE_NAT_PROXY:-true}" == "true" ]]; then
  for name in NAT_SSH_HOST NAT_SSH_PORT NAT_SSH_USER NAT_SSH_KEY_PATH; do
    require_env_present "$name"
  done
fi

log "Preflight passed. Sensitive values were not printed."
