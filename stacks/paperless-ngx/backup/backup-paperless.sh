#!/bin/sh
set -e

BACKUP_PATH="/home/julian/Desktop/homelab/stacks/paperless-ngx/backup/tmp"
SRC_EXPORT_PATH="/home/julian/Documents/paperless/export"
BORG_PATH="/media/julian/Elements/paperless-backups"

echo "Starting document exporter within Docker container"
docker exec -t paperless-ngx-webserver-1 document_exporter ../export
echo "Documents exported"

echo "Moving to $BACKUP_PATH"
mkdir -p "$BACKUP_PATH"
mv "$SRC_EXPORT_PATH"/* "$BACKUP_PATH"/

echo "Appending to borg repository"
borg create --stats --verbose --progress "$BORG_PATH::{now}" "$BACKUP_PATH"
echo "Archive created"

echo "Pruning old borg archives"
borg prune --keep-weekly=4 --keep-monthly=3 --progress "$BORG_PATH"
echo "Pruned old borg archives"

# echo "Compacting archives"
# borg compact --progress "$BORG_PATH"
# echo "Archives compacted"

echo "Cleaning up export files"
rm -r "$BACKUP_PATH"/
echo "Backup completed"
