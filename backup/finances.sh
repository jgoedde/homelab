#!/bin/sh
# Stops the finances stack and archives its data directory (SQLite db incl. WAL/SHM), .env, and compose.yml to the borg repo.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/bootstrap.sh"

require_root

STACK_DIR="/home/julian/Desktop/homelab/stacks/finances"
FINANCES_ENV="$STACK_DIR/.env"
FINANCES_COMPOSE="$STACK_DIR/compose.yml"
BACKUP_DIR="$STACK_DIR/data"
BORG_ARCHIVE_PREFIX="finances"

backup_start "Finances"

log "Stopping Finances Docker Compose"
docker compose --file "$FINANCES_COMPOSE" down

log "Creating Borg Archive..."
borg create --stats --verbose --progress \
    "$REPO::$BORG_ARCHIVE_PREFIX-{utcnow:%Y-%m-%d_%H-%M-%S}" \
    "$BACKUP_DIR" "$FINANCES_ENV" "$FINANCES_COMPOSE"
log "Archive created successfully"

log "Restarting Finances Docker Compose"
docker compose --file "$FINANCES_COMPOSE" up -d

prune_stack "$BORG_ARCHIVE_PREFIX"

backup_end
