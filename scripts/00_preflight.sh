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
  [[ "${ID:-}" == "ubuntu" ]] || warn "This project is designed for Ubuntu 22.04/24.04."
else
  warn "/etc/os-release not found"
fi

for name in \
  DEPLOY_DIR KEY_VAULTS_SECRET AUTH_SECRET POSTGRES_PASSWORD \
  RUSTFS_ACCESS_KEY RUSTFS_SECRET_KEY SEARXNG_SECRET; do
  require_env_not_placeholder "$name"
done

if [[ "${LOBE_PORT:-3210}" != "3210" ]]; then
  die "LOBE_PORT must stay 3210 in local-only host-network mode."
fi

if [[ -n "${OPENAI_API_KEY:-}${ANTHROPIC_API_KEY:-}${GOOGLE_API_KEY:-}${DEEPSEEK_API_KEY:-}${OPENROUTER_API_KEY:-}" ]]; then
  log "At least one model provider key is configured."
else
  warn "No model provider API key is configured yet. LobeHub can start, but model calls will fail until .env is filled."
fi

log "Preflight passed. Sensitive values were not printed."
