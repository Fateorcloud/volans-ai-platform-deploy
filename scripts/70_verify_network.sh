#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root

DEPLOY_DIR="${DEPLOY_DIR:-/opt/lobehub}"
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  load_env
  DEPLOY_DIR="${DEPLOY_DIR:-/opt/lobehub}"
elif [[ -f "$DEPLOY_DIR/.env" ]]; then
  ENV_FILE="$DEPLOY_DIR/.env" load_env
fi

log "Checking Docker Compose services"
if [[ -d "$DEPLOY_DIR" ]]; then
  (cd "$DEPLOY_DIR" && docker compose ps)
else
  die "Deploy directory not found: $DEPLOY_DIR"
fi

log "Checking local-only listeners"
ss -lntup | grep -E ":(3210|9000|9001|15432|16379|18080)\\b" || true
if ss -lntup | grep -Eq "0\\.0\\.0\\.0:(3210|9000|9001|15432|16379|18080)\\b|\\[::\\]:(3210|9000|9001|15432|16379|18080)\\b"; then
  die "Found a public listener for a local-only LobeHub port"
fi

log "Checking database, Redis, RustFS, and SearXNG"
(cd "$DEPLOY_DIR" && docker compose exec -T postgresql pg_isready -U postgres)
(cd "$DEPLOY_DIR" && docker compose exec -T redis redis-cli ping)
curl -fsS --max-time 10 "http://127.0.0.1:${RUSTFS_PORT:-9000}/health" >/dev/null
curl -fsS --max-time 10 "http://127.0.0.1:${SEARXNG_HOST_PORT:-18080}/config" >/dev/null || warn "SearXNG /config check failed; inspect lobe-searxng logs if search is unavailable."

log "Checking LobeHub HTTP entry"
curl -fsSI --max-time 20 "http://127.0.0.1:${LOBE_PORT:-3210}/" | head -5

log "Verification completed"
