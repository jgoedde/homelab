# shellcheck shell=sh
# Shared helpers for all stack backup scripts. Source this, don't execute it.

REPO="/media/julian/Elements/homelab-backup/repo"

# Pin borg's cache/config location so it's identical regardless of who
# invokes the script, instead of depending on root's/your $HOME.
export BORG_CACHE_DIR="/media/julian/Elements/homelab-backup/.borg-cache"
export BORG_CONFIG_DIR="/media/julian/Elements/homelab-backup/.borg-config"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root (sudo $0)" >&2
        exit 1
    fi
}

# Usage: backup_start <stack-name>
# Records the start time and stack name (for backup_end/prune_stack to use),
# and logs a start banner.
backup_start() {
    if [ -z "$1" ]; then
        echo "backup_start: missing required <stack-name> argument" >&2
        exit 1
    fi
    STACK_NAME="$1"
    START_TIME=$(date +%s)
    log "===== Starting $STACK_NAME backup ====="
}

backup_end() {
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    log "===== $STACK_NAME backup finished in ${ELAPSED}s ====="
}

# Usage: prune_stack <stack-name>
# Prunes only archives matching "<stack-name>-*" in the shared repo.
prune_stack() {
    if [ -z "$1" ]; then
        echo "prune_stack: missing required <stack-name> argument" >&2
        exit 1
    fi
    _PRUNE_STACK_NAME="$1"

    log "Pruning old $_PRUNE_STACK_NAME archives (keep-weekly=4, keep-monthly=3)..."
    borg prune --glob-archives "${_PRUNE_STACK_NAME}-*" \
        --keep-weekly=4 --keep-monthly=3 --progress "$REPO"
    log "Pruning complete"
}
