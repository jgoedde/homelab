#!/bin/sh
# Backs up the entire Karakeep app directory, .env, and compose.yml to a borg archive.
# This includes the Karakeep database and all uploaded files, archives, attachments etc., so it may be a bit larger.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/bootstrap.sh"

require_root

STACK_DIR="/home/julian/Desktop/homelab/stacks/karakeep"
KARAKEEP_DIR="/home/julian/Documents/karakeep-app"
KARAKEEP_ENV="$STACK_DIR/.env"
KARAKEEP_COMPOSE="$STACK_DIR/compose.yml"
BORG_ARCHIVE_PREFIX="karakeep"

backup_start "Karakeep"

log "Stopping Karakeep Docker Compose"
docker compose --file "$KARAKEEP_COMPOSE" down

log "Creating Borg Archive (data dir, .env, compose.yml)..."
borg create --stats --verbose --progress \
    "$REPO::$BORG_ARCHIVE_PREFIX-{utcnow:%Y-%m-%d_%H-%M-%S}" \
    "$KARAKEEP_DIR" "$KARAKEEP_ENV" "$KARAKEEP_COMPOSE"
log "Archive created successfully"

log "Restarting Karakeep Docker Compose"
docker compose --file "$KARAKEEP_COMPOSE" up -d

prune_stack "$BORG_ARCHIVE_PREFIX"

backup_end
