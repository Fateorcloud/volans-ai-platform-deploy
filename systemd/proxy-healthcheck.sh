#!/usr/bin/env bash
# Simple liveness probe for the host-side proxy on the Docker bridge gateway.
# Schedule via cron every minute; triggers systemd restart on failure.
#   * * * * * /opt/Serve/systemd/proxy-healthcheck.sh >> /var/log/proxy-health.log 2>&1

set -uo pipefail

AI_NET_GATEWAY="${AI_NET_GATEWAY:-172.18.0.1}"
PROXY_PORT="${PROXY_PORT:-7890}"
PROBE_URL="${PROBE_URL:-http://www.gstatic.com/generate_204}"
PROXY="${PROXY:-http://${AI_NET_GATEWAY}:${PROXY_PORT}}"
PROXY_RESTART_SERVICE="${PROXY_RESTART_SERVICE:-privoxy.service}"
TIMEOUT="${TIMEOUT:-8}"

if ! curl -sS --max-time "$TIMEOUT" -x "$PROXY" -o /dev/null -w '' "$PROBE_URL"; then
  echo "[$(date -Is)] proxy probe failed via $PROXY, restarting ${PROXY_RESTART_SERVICE}"
  systemctl restart "$PROXY_RESTART_SERVICE"
fi
