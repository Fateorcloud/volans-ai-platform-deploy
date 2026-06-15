#!/usr/bin/env bash
set -euo pipefail

allow_bridge() {
  local gateway="$1"
  local subnet="$2"
  local bridge_if

  bridge_if="$(ip -o addr show | awk -v gateway="${gateway}" '$4 ~ "^" gateway "/" {print $2; exit}')"

  if [ -z "${bridge_if:-}" ]; then
    echo "WARN: Docker bridge interface for ${gateway} not found; skipping"
    return 0
  fi

  iptables -D INPUT \
    -i "${bridge_if}" \
    -s "${subnet}" \
    -d "${gateway}" \
    -p tcp \
    --dport 7890 \
    -j ACCEPT 2>/dev/null || true

  iptables -I INPUT 1 \
    -i "${bridge_if}" \
    -s "${subnet}" \
    -d "${gateway}" \
    -p tcp \
    --dport 7890 \
    -j ACCEPT

  echo "OK: allowed Docker bridge ${bridge_if} -> ${gateway}:7890/tcp"
}

allow_bridge "172.18.0.1" "172.18.0.0/16"
allow_bridge "172.19.0.1" "172.19.0.0/16"
