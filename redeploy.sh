#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/julian/Desktop/homelab"

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

cd "$REPO_DIR"

OLD_HEAD=$(git rev-parse HEAD)
git fetch origin main
NEW_HEAD=$(git rev-parse origin/main)

if [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
    exit 0   # nothing changed, stay quiet
fi

log "Change detected: $OLD_HEAD -> $NEW_HEAD"

git merge --ff-only origin/main

# Only redeploy stacks whose files actually changed
CHANGED_STACKS=$(git diff --name-only "$OLD_HEAD" "$NEW_HEAD" -- stacks/ \
    | cut -d/ -f2 | sort -u)

if [ -z "$CHANGED_STACKS" ]; then
    log "No stack files changed, skipping redeploy."
    exit 0
fi

FAILED=0
DEPLOYED=0

for stack in $CHANGED_STACKS; do
    STACK_DIR="stacks/$stack"
    if [ -f "$STACK_DIR/compose.yml" ]; then
        log "Redeploying: $stack"
        if (
            cd "$STACK_DIR"
            docker compose pull && docker compose up -d
        ); then
            DEPLOYED=$((DEPLOYED + 1))
        else
            log "FAILED: $stack"
            FAILED=$((FAILED + 1))
        fi
    fi
done

# Prune only dangling (untagged) images that no container references.
# - No `-a`: tagged images (incl. ones for stopped stacks) are never touched.
# - No volumes/networks/containers: only images.
# - `until=24h`: skip images created in the last 24h (e.g. in-progress builds).
# - Skipped if any redeploy failed, so the previous image stays around for rollback.
# - Prune errors never abort the script.
if [ "$FAILED" -gt 0 ]; then
    log "Skipping image prune: $FAILED stack(s) failed."
elif [ "$DEPLOYED" -gt 0 ]; then
    log "Pruning dangling images..."
    docker image prune --force --filter "until=24h" \
        || log "Image prune failed (ignored)."
fi

log "Redeploy cycle complete."
