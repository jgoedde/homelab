#!/bin/sh
set -e

UPLOAD_LOCATION="/srv/secure/immich/library"
BACKUP_PATH="/media/julian/Elements/enc_immich-backups"

echo "Backing up Immich database"
docker exec -t immich_postgres pg_dumpall --clean --if-exists --username=postgres > "$UPLOAD_LOCATION"/database-backup/immich-database.sql
echo "Immich database backed up"

echo "Appending to borg repository"
borg create --stats --verbose --progress "$BACKUP_PATH/immich-borg::{now}" "$UPLOAD_LOCATION" --exclude "$UPLOAD_LOCATION"/thumbs/ --exclude "$UPLOAD_LOCATION"/encoded-video/
echo "Archive created"

echo "Pruning old borg archives"
borg prune --keep-weekly=4 --keep-monthly=3 --progress "$BACKUP_PATH"/immich-borg
echo "Pruned old borg archives"

# echo "Compacting archives"
# borg compact --progress "$BACKUP_PATH"/immich-borg
# echo "Archives compated"
