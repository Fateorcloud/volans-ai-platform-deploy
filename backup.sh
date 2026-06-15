#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/scripts/lib.sh" ]]; then
  # shellcheck source=scripts/lib.sh
  source "$SCRIPT_DIR/scripts/lib.sh"
elif [[ -f "$(dirname "$SCRIPT_DIR")/scripts/lib.sh" ]]; then
  # shellcheck source=scripts/lib.sh
  source "$(dirname "$SCRIPT_DIR")/scripts/lib.sh"
else
  printf '[lobehub-deploy][ERROR] Cannot find scripts/lib.sh\n' >&2
  exit 1
fi

require_root
load_env

DEPLOY_DIR="${DEPLOY_DIR:-/opt/lobehub}"
BACKUP_DIR="$DEPLOY_DIR/backup"
DATE="$(date +%F_%H%M%S)"
RETENTION="${BACKUP_RETENTION_DAYS:-14}"

if [[ ! -d "$DEPLOY_DIR" ]]; then
  die "Deploy directory not found: $DEPLOY_DIR"
fi

mkdir -p "$BACKUP_DIR"
cd "$DEPLOY_DIR"

docker compose exec -T postgresql pg_dump --clean --if-exists -U postgres "${LOBE_DB_NAME:-lobechat}" \
  | gzip > "$BACKUP_DIR/postgres_${LOBE_DB_NAME:-lobechat}_$DATE.sql.gz"

docker compose exec -T redis redis-cli BGSAVE >/dev/null || warn "Redis BGSAVE failed"

docker run --rm \
  --volumes-from lobe-rustfs \
  -v "$BACKUP_DIR:/backup" \
  alpine:3.20 \
  sh -c "cd /data && tar czf /backup/rustfs_data_$DATE.tar.gz ."

find "$BACKUP_DIR" -name 'postgres_*.sql.gz' -mtime +"$RETENTION" -delete
find "$BACKUP_DIR" -name 'rustfs_data_*.tar.gz' -mtime +"$RETENTION" -delete

log "Backup done:"
log "  $BACKUP_DIR/postgres_${LOBE_DB_NAME:-lobechat}_$DATE.sql.gz"
log "  $BACKUP_DIR/rustfs_data_$DATE.tar.gz"
