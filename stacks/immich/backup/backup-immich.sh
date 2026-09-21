#!/bin/sh
set -e

STACK_DIR="/home/julian/Desktop/homelab/stacks/immich"
IMMICH_ENV="$STACK_DIR/.env"
IMMICH_COMPOSE="$STACK_DIR/compose.yml"
UPLOAD_LOCATION="/srv/secure/immich/library"
BACKUP_PATH="/media/julian/Elements/enc_immich-backups"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

START_TIME=$(date +%s)

log "===== Starting Immich backup ====="

log "Dumping Immich database (pg_dumpall)..."

docker exec -t immich_postgres pg_dumpall \
    --clean --if-exists \
    --username=postgres > "$UPLOAD_LOCATION"/database-backup/immich-database.sql
log "Database dump complete -> $UPLOAD_LOCATION/database-backup/immich-database.sql"

log "Creating borg archive (library, .env, compose.yml) [sudo required for root-owned files]..."
sudo borg create --stats --verbose --progress \
    "$BACKUP_PATH/immich-borg::{utcnow:%Y-%m-%d_%H-%M-%S}" \
    "$UPLOAD_LOCATION" "$IMMICH_ENV" "$IMMICH_COMPOSE" \
    --exclude "$UPLOAD_LOCATION"/thumbs/ --exclude "$UPLOAD_LOCATION"/encoded-video/
log "Archive created successfully"

log "Pruning old borg archives (keep-weekly=4, keep-monthly=3)..."
borg prune --keep-weekly=4 --keep-monthly=3 --progress "$BACKUP_PATH"/immich-borg
log "Pruned old borg archives"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
log "===== Immich backup finished in ${ELAPSED}s ====="
