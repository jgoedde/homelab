#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/bootstrap.sh"

require_root

printf "Enter borg repository passphrase: "
stty -echo
read -r BORG_PASSPHRASE
stty echo
echo
export BORG_PASSPHRASE

log "===== Running all stack backups ====="

"$SCRIPT_DIR/immich.sh"
"$SCRIPT_DIR/karakeep.sh"
"$SCRIPT_DIR/paperless.sh"

log "===== All stack backups complete ====="
