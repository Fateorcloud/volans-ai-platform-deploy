#!/usr/bin/env bash
set -euo pipefail

PROXY_PORT="${PROXY_PORT:-7890}"
AI_NET_GATEWAY="${AI_NET_GATEWAY:-172.18.0.1}"
AI_NET_SUBNET="${AI_NET_SUBNET:-172.18.0.0/16}"
XUI_NET_GATEWAY="${XUI_NET_GATEWAY:-172.19.0.1}"
XUI_NET_SUBNET="${XUI_NET_SUBNET:-172.19.0.0/16}"

allow_bridge() {
  local gateway="$1"
  local subnet="$2"
  local bridge_if

  bridge_if="$(ip -o addr show | awk -v gateway="${gateway}" '$4 ~ "^" gateway "/" {print $2; exit}')"

  if [[ -z "${bridge_if:-}" ]]; then
    echo "WARN: Docker bridge interface for ${gateway} not found; skipping"
    return 0
  fi

  iptables -D INPUT \
    -i "${bridge_if}" \
    -s "${subnet}" \
    -d "${gateway}" \
    -p tcp \
    --dport "${PROXY_PORT}" \
    -j ACCEPT 2>/dev/null || true

  iptables -I INPUT 1 \
    -i "${bridge_if}" \
    -s "${subnet}" \
    -d "${gateway}" \
    -p tcp \
    --dport "${PROXY_PORT}" \
    -j ACCEPT

  echo "OK: allowed Docker bridge ${bridge_if} -> ${gateway}:${PROXY_PORT}/tcp"
}

allow_bridge "${AI_NET_GATEWAY}" "${AI_NET_SUBNET}"

if ip addr show | grep -q "${XUI_NET_GATEWAY}/"; then
  allow_bridge "${XUI_NET_GATEWAY}" "${XUI_NET_SUBNET}"
fi
