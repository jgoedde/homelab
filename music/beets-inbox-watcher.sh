#!/usr/bin/env bash
set -euo pipefail

INBOX="$HOME/Music/inbox-metube"
STABLE_SECONDS=60   # Datei/Ordner muss seit N Sekunden unverändert sein

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
            continue
        fi
        log "Importing album: $base"
        if /home/julian/.local/bin/beet import -q "$entry"; then
            log "✓ Album imported"
        else
            log "✗ Album import failed"
        fi

    elif [[ -f "$entry" ]]; then
        if ! is_stable "$entry"; then
            log "⏳ Skipping singleton (still changing): $base"
            continue
        fi
        log "Importing singleton: $base"
        if /home/julian/.local/bin/beet import --singleton -q "$entry"; then
            log "✓ Singleton imported"
        else
            log "✗ Singleton import failed"
        fi
    fi
done
