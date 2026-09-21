#!/bin/sh
# Backs up Paperless-ngx export files, .env, and compose.yml to a borg archive.
# Uses the document exporter recommended by Paperless-ngx to export all documents to a single directory.
# See https://docs.paperless-ngx.com/administration/
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/bootstrap.sh"

require_root

STACK_DIR="/home/julian/Desktop/homelab/stacks/paperless-ngx"
PAPERLESS_ENV="$STACK_DIR/.env"
PAPERLESS_COMPOSE="$STACK_DIR/compose.yml"
SRC_EXPORT_PATH="/home/julian/Documents/paperless/export"
BORG_ARCHIVE_PREFIX="paperless"

backup_start "Paperless-ngx"

log "Running document_exporter inside paperless-ngx-webserver-1..."
docker exec -t paperless-ngx-webserver-1 document_exporter ../export
log "Document export complete"

log "Creating borg archive (export, .env, compose.yml)..."
borg create --stats --verbose --progress \
    "$REPO::$BORG_ARCHIVE_PREFIX-{utcnow:%Y-%m-%d_%H-%M-%S}" \
    "$SRC_EXPORT_PATH" "$PAPERLESS_ENV" "$PAPERLESS_COMPOSE"
log "Archive created successfully"

prune_stack "$BORG_ARCHIVE_PREFIX"

log "Cleaning up export files at $SRC_EXPORT_PATH..."
rm -rf "${SRC_EXPORT_PATH:?}"/*
log "Cleanup complete"

backup_end
