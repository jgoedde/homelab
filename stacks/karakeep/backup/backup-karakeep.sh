#!/bin/sh
set -e

STACK_DIR="/home/julian/Desktop/homelab/stacks/karakeep"
KARAKEEP_DIR="/home/julian/Documents/karakeep-app"
KARAKEEP_ENV="$STACK_DIR/.env"
KARAKEEP_COMPOSE="$STACK_DIR/compose.yml"
BACKUP_PATH="/media/julian/Elements/enc_karakeep-backups"

echo "Stopping karakeep compose"
docker compose --file "$KARAKEEP_COMPOSE" down

echo "Backing up Karakeep data dir, env, and compose file using sudo"
sudo borg create --stats --verbose --progress "$BACKUP_PATH/karakeep-borg::{now}" \
    "$KARAKEEP_DIR" "$KARAKEEP_ENV" "$KARAKEEP_COMPOSE"
echo "Archive created"

echo "Restarting karakeep compose"
docker compose --file "$KARAKEEP_COMPOSE" up -d

echo "Pruning old backups"
borg prune --keep-weekly=4 --keep-monthly=3 --progress "$BACKUP_PATH"/karakeep-borg
echo "Pruned old backups"
