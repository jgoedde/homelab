#!/usr/bin/env bash
set -euo pipefail

INBOX="$HOME/Music/inbox-metube"
STATS_DIR="$HOME/Music/stats"
STABLE_SECONDS=60   # Datei/Ordner muss seit N Sekunden unverändert sein
BEET="/home/julian/.local/bin/beet"

mkdir -p "$STATS_DIR"

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

# Prüft, ob eine Datei seit STABLE_SECONDS nicht mehr verändert wurde
is_stable() {
    local target="$1"
    local now mtime age
    now=$(date +%s)
    mtime=$(stat -c %Y "$target")
    age=$(( now - mtime ))
    (( age >= STABLE_SECONDS ))
}

# Für Ordner: NUR stabil, wenn WIRKLICH jede Datei drin stabil ist
# (verhindert, dass ein Album importiert wird, während noch Tracks nachladen)
dir_is_stable() {
    local dir="$1"
    local f
    while IFS= read -r -d '' f; do
        is_stable "$f" || return 1
    done < <(find "$dir" -type f -print0)
    return 0
}

write_cron_status() {
    cat > "$STATS_DIR/cron-status.json" <<EOF
{
  "lastRun": "$RUN_START",
  "status": "$1",
  "imported": $IMPORTED,
  "failed": $FAILED,
  "skipped": $SKIPPED
}
EOF
}

write_beets_stats() {
    local raw tracks artists albums total_time total_size
    raw=$("$BEET" stats -e)
    tracks=$(awk -F': ' '/^Tracks:/{print $2}' <<< "$raw")
    artists=$(awk -F': ' '/^Artists:/{print $2}' <<< "$raw")
    albums=$(awk -F': ' '/^Albums:/{print $2}' <<< "$raw")
    total_time=$(awk -F': ' '/^Total time:/{print $2}' <<< "$raw")
    total_size=$(awk -F': ' '/^Total size:/{print $2}' <<< "$raw")

    cat > "$STATS_DIR/beets-stats.json" <<EOF
{
  "tracks": ${tracks:-0},
  "artists": ${artists:-0},
  "albums": ${albums:-0},
  "totalTime": "${total_time:-unknown}",
  "totalSize": "${total_size:-unknown}",
  "updated": "$RUN_START"
}
EOF
}

RUN_START=$(date -Iseconds)
IMPORTED=0
FAILED=0
SKIPPED=0

# Falls irgendwas unerwartetes crasht (z.B. mkdir/find), Status trotzdem schreiben
trap 'write_cron_status "error"' ERR

shopt -s nullglob
for entry in "$INBOX"/*; do
    base="$(basename "$entry")"

    # MeTube-Metadaten ignorieren
    [[ "$base" == ".metube" ]] && continue

    # Unfertige yt-dlp/MeTube-Zwischendateien ignorieren (.part, .ytdl, .tmp)
    [[ "$base" == *.part || "$base" == *.ytdl || "$base" == *.tmp ]] && continue

    if [[ -d "$entry" ]]; then
        if ! dir_is_stable "$entry"; then
            log "⏳ Skipping album (still changing): $base"
            ((SKIPPED++))
            continue
        fi
        log "Importing album: $base"
        if "$BEET" import -q "$entry"; then
            log "✓ Album imported"
            rm -rf "$entry"  # Delete the directory after successful import
            ((IMPORTED++))
        else
            log "✗ Album import failed"
            ((FAILED++))
        fi
    elif [[ -f "$entry" ]]; then
        if ! is_stable "$entry"; then
            log "⏳ Skipping singleton (still changing): $base"
            ((SKIPPED++))
            continue
        fi
        log "Importing singleton: $base"
        if "$BEET" import --singleton -q "$entry"; then
            log "✓ Singleton imported"
            ((IMPORTED++))
        else
            log "✗ Singleton import failed"
            ((FAILED++))
        fi
    fi
done

if (( FAILED > 0 )); then
    write_cron_status "partial"
elif (( IMPORTED == 0 )); then
    write_cron_status "idle"
else
    write_cron_status "success"
fi

write_beets_stats
