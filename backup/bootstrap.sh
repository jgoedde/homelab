# shellcheck shell=sh
# Shared helpers for all stack backup scripts. Source this, don't execute it.

REPO="/media/julian/Elements/homelab-backup/repo"

# Pin borg's cache/config location so it's identical regardless of who
# invokes the script, instead of depending on root's/your $HOME.
export BORG_CACHE_DIR="/media/julian/Elements/homelab-backup/.borg-cache"
export BORG_CONFIG_DIR="/media/julian/Elements/homelab-backup/.borg-config"

LOG_FILE="$SCRIPT_DIR/backup.log"
LOG_MAX_BYTES=1048576
LOG_KEEP=5

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

# Shifts backup.log -> backup.log.1 -> ... -> backup.log.$LOG_KEEP once it exceeds $LOG_MAX_BYTES.
rotate_log() {
    if [ ! -f "$LOG_FILE" ] || [ "$(wc -c < "$LOG_FILE")" -lt "$LOG_MAX_BYTES" ]; then
        return 0
    fi
    _LOG_I=$LOG_KEEP
    while [ "$_LOG_I" -gt 1 ]; do
        _LOG_PREV=$((_LOG_I - 1))
        if [ -f "$LOG_FILE.$_LOG_PREV" ]; then
            mv "$LOG_FILE.$_LOG_PREV" "$LOG_FILE.$_LOG_I"
        fi
        _LOG_I=$_LOG_PREV
    done
    mv "$LOG_FILE" "$LOG_FILE.1"
}

# Mirrors all stdout/stderr of the script to $LOG_FILE (POSIX sh has no process
# substitution, so tee reads from a FIFO). Child backup scripts inherit the
# redirected output, so only the outermost script sets this up.
start_logging() {
    if [ -n "$BACKUP_LOGGING" ]; then
        return 0
    fi
    export BACKUP_LOGGING=1
    rotate_log
    _LOG_FIFO=$(mktemp -u)
    mkfifo "$_LOG_FIFO"
    tee -a "$LOG_FILE" < "$_LOG_FIFO" &
    _LOG_TEE_PID=$!
    exec > "$_LOG_FIFO" 2>&1
    rm "$_LOG_FIFO"
    # Close our end so tee sees EOF, and wait so its last lines land before the prompt returns.
    trap 'exec >&- 2>&-; wait "$_LOG_TEE_PID"' EXIT
}

# Non-root runs get rejected by require_root; don't let them create or append to the log.
if [ "$(id -u)" -eq 0 ]; then
    start_logging
fi
