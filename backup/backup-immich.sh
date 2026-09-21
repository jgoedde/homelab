#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/backup-common.sh"

require_root

STACK_DIR="/home/julian/Desktop/homelab/stacks/immich"
IMMICH_ENV="$STACK_DIR/.env"
IMMICH_COMPOSE="$STACK_DIR/compose.yml"
UPLOAD_LOCATION="/srv/secure/immich/library"
BORG_ARCHIVE_PREFIX="immich"

backup_start "Immich"

log "Dumping Immich database (pg_dumpall)..."
docker exec -t immich_postgres pg_dumpall \
    --clean --if-exists \
    --username=postgres > "$UPLOAD_LOCATION"/database-backup/immich-database.sql
log "Database dump complete -> $UPLOAD_LOCATION/database-backup/immich-database.sql"

log "Creating borg archive (library, .env, compose.yml)..."
borg create --stats --verbose --progress \
    "$REPO::$BORG_ARCHIVE_PREFIX-{utcnow:%Y-%m-%d_%H-%M-%S}" \
    "$UPLOAD_LOCATION" "$IMMICH_ENV" "$IMMICH_COMPOSE" \
    --exclude "$UPLOAD_LOCATION"/thumbs/ --exclude "$UPLOAD_LOCATION"/encoded-video/
log "Archive created successfully"

prune_stack "$BORG_ARCHIVE_PREFIX"

backup_end
