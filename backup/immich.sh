#!/bin/sh
# Dumps Immich database (pg_dump) and creates a borg archive including .env and compose.yml
# Excludes thumbnails and encoded videos from the backup.
# https://docs.immich.app/administration/backup-and-restore/
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/bootstrap.sh"

require_root

STACK_DIR="/home/julian/Desktop/homelab/stacks/immich"
IMMICH_ENV="$STACK_DIR/.env"
IMMICH_COMPOSE="$STACK_DIR/compose.yml"
UPLOAD_LOCATION="/srv/secure/immich/library"
BORG_ARCHIVE_PREFIX="immich"

backup_start "Immich"

log "Dumping Immich database (pg_dump)..."
# https://docs.immich.app/administration/backup-and-restore/#restore-cli
docker exec -t immich_postgres pg_dump \
    --clean --if-exists \
    --dbname=immich --username=postgres | gzip > "$UPLOAD_LOCATION"/database-backup/immich-database.sql.gz
log "Database dump complete -> $UPLOAD_LOCATION/database-backup/immich-database.sql.gz"

log "Creating borg archive (library, .env, compose.yml)..."
borg create --stats --verbose --progress \
    "$REPO::$BORG_ARCHIVE_PREFIX-{utcnow:%Y-%m-%d_%H-%M-%S}" \
    "$UPLOAD_LOCATION" "$IMMICH_ENV" "$IMMICH_COMPOSE" \
    --exclude "$UPLOAD_LOCATION"/thumbs/ --exclude "$UPLOAD_LOCATION"/encoded-video/
log "Archive created successfully"

prune_stack "$BORG_ARCHIVE_PREFIX"

backup_end
