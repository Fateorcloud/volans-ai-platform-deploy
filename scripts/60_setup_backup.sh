#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

DEPLOY_DIR="${DEPLOY_DIR:-/opt/Serve}"
CRON_TIME="${BACKUP_CRON_TIME:-30 3 * * *}"
CRON_LINE="$CRON_TIME $DEPLOY_DIR/backup/pg_dump.sh >> /var/log/ai-platform-backup.log 2>&1"

install_template "$PROJECT_ROOT/backup.sh" "$DEPLOY_DIR/backup/pg_dump.sh" 0755

tmp="$(mktemp)"
crontab -l > "$tmp" 2>/dev/null || true
grep -v 'ai-platform-backup.log' "$tmp" > "$tmp.next" || true
printf '%s\n' "$CRON_LINE" >> "$tmp.next"
crontab "$tmp.next"
rm -f "$tmp" "$tmp.next"

log "Backup cron installed"

