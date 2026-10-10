#!/bin/sh
# Puts the latest entry from the finances backup folder into the borg repo as an archive.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/bootstrap.sh"

require_root

STACK_DIR="/home/julian/Desktop/homelab/stacks/finances"
FINANCES_COMPOSE="$STACK_DIR/compose.yml"
BACKUP_DIR="/home/julian/Documents/finances-backups"
BORG_ARCHIVE_PREFIX="finances"

backup_start "Finances"

log "Stopping Finances Docker Compose"
docker compose --file "$FINANCES_COMPOSE" down

# File names start with an ISO datetime, so lexical order == chronological order.
LATEST_DB=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*-finance.db' | sort | tail -n 1)
if [ -z "$LATEST_DB" ]; then
    echo "No *-finance.db file found in $BACKUP_DIR" >&2
    exit 1
fi
log "Latest finances backup: $LATEST_DB"

log "Creating Borg Archive..."
borg create --stats --verbose --progress \
    "$REPO::$BORG_ARCHIVE_PREFIX-{utcnow:%Y-%m-%d_%H-%M-%S}" \
    "$LATEST_DB"
log "Archive created successfully"

log "Restarting Finances Docker Compose"
docker compose --file "$FINANCES_COMPOSE" up -d

prune_stack "$BORG_ARCHIVE_PREFIX"

backup_end
