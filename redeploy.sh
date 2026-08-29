#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/julian/Desktop/homelab"
LOG_FILE="/var/log/homelab-redeploy.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

cd "$REPO_DIR"

OLD_HEAD=$(git rev-parse HEAD)

git fetch origin main >> "$LOG_FILE" 2>&1

NEW_HEAD=$(git rev-parse origin/main)

if [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
    exit 0   # nothing changed, stay quiet
fi

log "Change detected: $OLD_HEAD -> $NEW_HEAD"

git merge --ff-only origin/main >> "$LOG_FILE" 2>&1

# Only redeploy stacks whose files actually changed
CHANGED_STACKS=$(git diff --name-only "$OLD_HEAD" "$NEW_HEAD" -- stacks/ \
    | cut -d/ -f2 | sort -u)

if [ -z "$CHANGED_STACKS" ]; then
    log "No stack files changed, skipping redeploy."
    exit 0
fi

for stack in $CHANGED_STACKS; do
    STACK_DIR="stacks/$stack"
    if [ -f "$STACK_DIR/compose.yml" ]; then
        log "Redeploying: $stack"
        (
            cd "$STACK_DIR"
            docker compose pull
            docker compose up -d
        ) >> "$LOG_FILE" 2>&1 || log "FAILED: $stack"
    fi
done

log "Redeploy cycle complete."
