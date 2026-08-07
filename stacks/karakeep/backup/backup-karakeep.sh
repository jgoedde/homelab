#!/bin/sh
set -e

KARAKEEP_JSON="./karakeep-backup.json"
BACKUP_PATH="/media/julian/Elements/enc_karakeep-backups"

echo "Backing up Karakeep JSON"
borg create --stats --verbose --progress "$BACKUP_PATH/karakeep-borg::{now}" "$KARAKEEP_JSON"
echo "Archive created"

echo "Pruning old backups"
borg prune --keep-weekly=4 --keep-monthly=3 --progress "$BACKUP_PATH"/karakeep-borg
echo "Pruned old backups"
