#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../backup-common.sh"

STACK_DIR="/home/julian/Desktop/homelab/stacks/paperless-ngx"
PAPERLESS_ENV="$STACK_DIR/.env"
PAPERLESS_COMPOSE="$STACK_DIR/compose.yml"
TMP_EXPORT_PATH="$SCRIPT_DIR/tmp"
SRC_EXPORT_PATH="/home/julian/Documents/paperless/export"
BORG_ARCHIVE_PREFIX="paperless"

backup_start "Paperless-ngx"

log "Running document_exporter inside paperless-ngx-webserver-1..."
docker exec -t paperless-ngx-webserver-1 document_exporter ../export
log "Document export complete"

log "Moving exported files to $TMP_EXPORT_PATH..."
mkdir -p "$TMP_EXPORT_PATH"
mv "$SRC_EXPORT_PATH"/* "$TMP_EXPORT_PATH"/
log "Move complete"

log "Creating borg archive (export, .env, compose.yml)..."
borg create --stats --verbose --progress \
    "$REPO::$BORG_ARCHIVE_PREFIX-{utcnow:%Y-%m-%d_%H-%M-%S}" \
    "$TMP_EXPORT_PATH" "$PAPERLESS_ENV" "$PAPERLESS_COMPOSE"
log "Archive created successfully"

prune_stack "$BORG_ARCHIVE_PREFIX"

log "Cleaning up temporary export files at $TMP_EXPORT_PATH..."
rm -r "$TMP_EXPORT_PATH"
log "Cleanup complete"

backup_end
