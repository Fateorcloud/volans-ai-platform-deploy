#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root

DEPLOY_DIR="${DEPLOY_DIR:-/opt/Serve}"
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  load_env
  DEPLOY_DIR="${DEPLOY_DIR:-/opt/Serve}"
elif [[ -f "$DEPLOY_DIR/.env" ]]; then
  ENV_FILE="$DEPLOY_DIR/.env" load_env
fi

log "Checking Docker Compose services"
if [[ -d "$DEPLOY_DIR" ]]; then
  (cd "$DEPLOY_DIR" && docker compose ps)
else
  warn "Deploy directory not found: $DEPLOY_DIR"
fi

XUI_DEPLOY_DIR="${XUI_DEPLOY_DIR:-$DEPLOY_DIR/xui}"
if [[ -d "$XUI_DEPLOY_DIR" ]]; then
  (cd "$XUI_DEPLOY_DIR" && docker compose ps)
else
  warn "3xui deploy directory not found: $XUI_DEPLOY_DIR"
fi

log "Checking listen sockets"
ss -lntup | grep -E '10808|7890|3000|8080|5432|29222|31444|80|443|22' || true
if ss -lntup | grep -Eq '0\.0\.0\.0:7890|\*:7890|\[::\]:7890'; then
  die "Unsafe public 7890 listener found"
fi

log "Checking ai-proxy-firewall rule"
iptables -S INPUT | grep -- '--dport 7890' || warn "No INPUT rule for 7890 found"

log "Checking Open WebUI public config"
if docker network inspect ai-platform_ai-net >/dev/null 2>&1; then
  docker run --rm --network ai-platform_ai-net curlimages/curl:8.10.1 \
    -sS --max-time 10 http://open-webui:8080/api/config | jq '.features.enable_signup, .features.enable_api_keys' || true
else
  warn "Docker network ai-platform_ai-net not found"
fi

log "Checking egress IPs"
host_direct="$(curl -4s --max-time 10 https://api.ipify.org || true)"
host_proxy="$(curl -x http://172.18.0.1:7890 -4s --max-time 15 https://api.ipify.org || true)"
docker_proxy=""
xui_direct=""
xui_proxy=""
if docker network inspect ai-platform_ai-net >/dev/null 2>&1; then
  docker_proxy="$(docker run --rm --network ai-platform_ai-net curlimages/curl:8.10.1 \
    -x http://172.18.0.1:7890 -4s --max-time 20 https://api.ipify.org || true)"
fi
if docker network inspect xui_default >/dev/null 2>&1; then
  xui_direct="$(docker run --rm --network xui_default curlimages/curl:8.10.1 \
    -4s --max-time 20 https://api.ipify.org || true)"
  xui_proxy="$(docker run --rm --network xui_default curlimages/curl:8.10.1 \
    -x http://172.19.0.1:7890 -4s --max-time 20 https://api.ipify.org || true)"
fi

printf 'host direct = %s\n' "${host_direct:-unavailable}"
printf 'host via privoxy = %s\n' "${host_proxy:-unavailable}"
printf 'docker via privoxy = %s\n' "${docker_proxy:-unavailable}"
printf 'xui direct = %s\n' "${xui_direct:-unavailable}"
printf 'xui via privoxy = %s\n' "${xui_proxy:-unavailable}"

log "Checking proxy environment"
docker exec newapi printenv HTTP_PROXY 2>/dev/null || true
docker exec newapi printenv http_proxy 2>/dev/null || true
if docker exec open-webui printenv HTTP_PROXY >/dev/null 2>&1; then
  die "open-webui should not set HTTP_PROXY"
fi

log "Verification completed"
