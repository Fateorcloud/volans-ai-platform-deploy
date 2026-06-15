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
  printf '[volans][ERROR] Cannot find scripts/lib.sh\n' >&2
  exit 1
fi

require_root
load_env

DEPLOY_DIR="${DEPLOY_DIR:-/opt/Serve}"
BACKUP_DIR="$DEPLOY_DIR/backup"
DATE="$(date +%F_%H%M%S)"
RETENTION="${BACKUP_RETENTION_DAYS:-14}"

if [[ ! -d "$DEPLOY_DIR" ]]; then
  die "Deploy directory not found: $DEPLOY_DIR"
fi

mkdir -p "$BACKUP_DIR"
cd "$DEPLOY_DIR"

docker compose exec -T postgres pg_dumpall -U "${DB_USER:-ai_admin}" \
  > "$BACKUP_DIR/postgres_all_$DATE.sql"
gzip "$BACKUP_DIR/postgres_all_$DATE.sql"
find "$BACKUP_DIR" -name 'postgres_all_*.sql.gz' -mtime +"$RETENTION" -delete

log "Backup done: $BACKUP_DIR/postgres_all_$DATE.sql.gz"
