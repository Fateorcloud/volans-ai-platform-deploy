#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0

scan_pattern() {
  local name="$1"
  local pattern="$2"
  local output

  output="$(
    find "$ROOT" \
      -path "$ROOT/.git" -prune -o \
      -path "$ROOT/postgres_data" -prune -o \
      -path "$ROOT/redis_data" -prune -o \
      -path "$ROOT/rustfs_data" -prune -o \
      -path "$ROOT/backup" -prune -o \
      -type f \
      ! -name '*.zip' \
      ! -name '*.tgz' \
      ! -name '*.tar.gz' \
      ! -name '*.7z' \
      ! -name '*.rar' \
      -print0 |
      xargs -0 grep -nEI "$pattern" 2>/dev/null || true
  )"

  if [[ -n "$output" ]]; then
    printf '[security-scan][FAIL] %s\n%s\n' "$name" "$output" >&2
    fail=1
  fi
}

scan_pattern "OpenAI-compatible token" '(^|[^A-Za-z0-9_])(sk-[A-Za-z0-9_-]{20,})'
scan_pattern "GitHub token" '(ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})'
scan_pattern "Private key" 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY'
scan_pattern "Cloudflare JWT-like token" 'eyJ[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{20,}'
scan_pattern "Production Volans domain" '(^|[^A-Za-z0-9.-])([A-Za-z0-9-]+\.)?volans\.one([^A-Za-z0-9.-]|$)'
scan_pattern "Known production IP" '(203\.9\.150\.170|141\.239\.74\.52)'

if [[ "$fail" -ne 0 ]]; then
  cat >&2 <<'MSG'
[security-scan] Potential public-release issues found.
Review each match. Use placeholders for docs/examples and keep real secrets out of Git.
MSG
  exit 1
fi

printf '[security-scan] OK: no obvious public-release secrets found.\n'
