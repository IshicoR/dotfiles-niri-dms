#!/usr/bin/env bash
# apply-wallpapers.sh — install bundled wallpapers + seed DMS wallpaper state.
#
# Independent of bootstrap.sh: run this any time you want to (re)deploy the
# rose-pine wallpaper set and point DMS at it. Safe to re-run.
#
# What it does:
#   1. rsync wallpapers/rose-pine/ → ~/.local/share/wallpapers/rose-pine/
#   2. write dms-state/{session,cache}.json into
#      ~/.local/state/DankMaterialShell/, expanding __HOME__ → $HOME
#      (existing files get a timestamped .bak)
#   3. if dms.service is running, restart it (cheaper) or call
#      `dms ipc call wallpaper set <default>` to re-pick up the change

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_WP="$REPO_DIR/wallpapers"
SRC_STATE="$REPO_DIR/dms-state"
DST_WP="$HOME/.local/share/wallpapers"
DST_STATE="$HOME/.local/state/DankMaterialShell"
TS="$(date +%Y%m%d-%H%M%S)"

log() { printf '\033[1;36m[wallpapers]\033[0m %s\n' "$*"; }

[ -d "$SRC_WP" ]    || { echo "missing $SRC_WP" >&2; exit 1; }
[ -d "$SRC_STATE" ] || { echo "missing $SRC_STATE" >&2; exit 1; }

# 1. wallpaper files
log "syncing wallpapers → $DST_WP/"
mkdir -p "$DST_WP"
rsync -a --delete "$SRC_WP/" "$DST_WP/"

# 2. DMS state (with __HOME__ expansion)
log "seeding DMS state → $DST_STATE/"
mkdir -p "$DST_STATE"
for f in session.json cache.json; do
    src="$SRC_STATE/$f"
    dst="$DST_STATE/$f"
    [ -f "$src" ] || continue
    if [ -f "$dst" ]; then
        cp -a "$dst" "$dst.bak.$TS"
        log "  backed up existing $f → $f.bak.$TS"
    fi
    sed "s|__HOME__|$HOME|g" "$src" > "$dst"
    log "  wrote $f"
done

# 3. nudge DMS so it re-reads state (only if it's running)
if systemctl --user is-active --quiet dms.service 2>/dev/null; then
    # Force DMS to pick the wallpaper from session.json by IPC-setting it.
    wp="$(jq -r '.wallpaperPath' "$DST_STATE/session.json")"
    if [ -n "$wp" ] && [ -f "$wp" ]; then
        log "telling DMS to load: $wp"
        dms ipc call wallpaper set "$wp" >/dev/null 2>&1 || \
            systemctl --user restart dms.service
    else
        log "wallpaperPath in session.json doesn't resolve — restarting dms.service"
        systemctl --user restart dms.service
    fi
else
    log "dms.service not running — skipping live update (state will be picked up on next launch)"
fi

log "done."
