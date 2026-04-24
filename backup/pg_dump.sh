#!/usr/bin/env bash
# Daily PostgreSQL logical backup for the ai-platform stack.
# Usage (crontab):
#   0 3 * * * /opt/ai-platform/backup/pg_dump.sh >> /var/log/pgdump.log 2>&1
#
# Optional offsite upload: set RCLONE_REMOTE to something like "r2:ai-backup"
# and install rclone. Empty = local-only.

set -euo pipefail

STACK_DIR="${STACK_DIR:-/opt/ai-platform}"
BACKUP_DIR="${BACKUP_DIR:-${STACK_DIR}/backup}"
RETAIN_DAYS="${RETAIN_DAYS:-14}"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"

# Load DB credentials from the stack's .env so we don't hardcode them.
if [[ -f "${STACK_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "${STACK_DIR}/.env" && set +a
fi

: "${DB_USER:?DB_USER not set - check ${STACK_DIR}/.env}"

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="${BACKUP_DIR}/pgdump_${STAMP}.sql.gz"

docker exec postgres pg_dumpall -U "${DB_USER}" \
  | gzip -9 > "$OUT"

echo "[$(date -Is)] backup written: $OUT ($(du -h "$OUT" | cut -f1))"

# Prune old local backups.
find "$BACKUP_DIR" -name 'pgdump_*.sql.gz' -mtime +"${RETAIN_DAYS}" -print -delete || true

# Optional offsite sync.
if [[ -n "$RCLONE_REMOTE" ]] && command -v rclone >/dev/null 2>&1; then
  rclone copy "$OUT" "$RCLONE_REMOTE" --quiet
  echo "[$(date -Is)] uploaded to $RCLONE_REMOTE"
fi
