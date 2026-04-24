#!/usr/bin/env bash
# Simple liveness probe for the host-side proxy on :7890.
# Schedule via cron every minute; triggers systemd restart on failure.
#   * * * * * /opt/ai-platform/systemd/proxy-healthcheck.sh >> /var/log/proxy-health.log 2>&1

set -uo pipefail

PROBE_URL="${PROBE_URL:-https://www.gstatic.com/generate_204}"
PROXY="${PROXY:-http://127.0.0.1:7890}"
TIMEOUT="${TIMEOUT:-8}"

if ! curl -sS --max-time "$TIMEOUT" -x "$PROXY" -o /dev/null -w '' "$PROBE_URL"; then
  echo "[$(date -Is)] proxy probe failed via $PROXY, restarting clash.service"
  systemctl restart clash.service
fi
