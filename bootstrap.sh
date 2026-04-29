#!/usr/bin/env bash
# bootstrap.sh — install niri + DankMaterialShell on a fresh Fedora host.
#
# Steps:
#   1. enable required COPRs                (packages/repos.sh)
#   2. dnf install everything in core.txt
#   3. back up existing dotfile targets, then rsync home/ → $HOME
#      (also expand __HOME__ placeholders inside settings.json)
#   4. mirror /usr/share/quickshell/dms into ~/.config/quickshell/dms via cp -as
#   5. drop the local QML overrides from overlay/quickshell-dms/
#   6. systemctl --user daemon-reload && enable --now dms.service
#
# Re-running is safe: backups are timestamped, rsync overwrites, the overlay
# step replaces only the symlinks we override.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.local/state/dotfiles-niri-dms/backups/$TS"

log() { printf '\033[1;36m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[bootstrap]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "do not run as root — sudo is invoked where needed"

# --- 1. repos --------------------------------------------------------------
log "enabling COPRs / RPMFusion"
bash "$REPO_DIR/packages/repos.sh"

# --- 2. packages -----------------------------------------------------------
log "installing packages from packages/core.txt"
mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$REPO_DIR/packages/core.txt")
sudo dnf install -y "${pkgs[@]}"

# --- 3. dotfiles -----------------------------------------------------------
log "backing up existing targets to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    target="$HOME/$rel"
    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -a "$target" "$BACKUP_DIR/$rel"
    fi
done < <(cd "$REPO_DIR/home" && find . -type f -print0)

log "syncing dotfiles into \$HOME"
rsync -a "$REPO_DIR/home/" "$HOME/"

# Expand __HOME__ placeholder in DMS settings.json (DMS doesn't expand ~).
SETTINGS="$HOME/.config/DankMaterialShell/settings.json"
if [ -f "$SETTINGS" ] && grep -q "__HOME__" "$SETTINGS"; then
    sed -i "s|__HOME__|$HOME|g" "$SETTINGS"
    log "expanded __HOME__ in settings.json"
fi
# Wallpapers + DMS session/cache state are intentionally not handled here —
# run scripts/apply-wallpapers.sh separately for those.

# --- 4. quickshell/dms overlay mirror -------------------------------------
SYS_DMS=/usr/share/quickshell/dms
USER_DMS="$HOME/.config/quickshell/dms"
if [ ! -d "$SYS_DMS" ]; then
    die "$SYS_DMS not found — DMS package didn't install correctly"
fi

log "rebuilding quickshell/dms symlink mirror at $USER_DMS"
# Stale mirror: nuke it (only contains symlinks + our overrides). Anything the
# user actually customised is preserved in the timestamped backup above.
if [ -d "$USER_DMS" ]; then
    rm -rf "$USER_DMS"
fi
mkdir -p "$(dirname "$USER_DMS")"
cp -as "$SYS_DMS" "$USER_DMS"

# --- 5. drop overlay overrides --------------------------------------------
OVERLAY="$REPO_DIR/overlay/quickshell-dms"
if [ -d "$OVERLAY" ]; then
    log "applying QML overrides from overlay/"
    while IFS= read -r -d '' src; do
        rel="${src#$OVERLAY/}"
        dst="$USER_DMS/$rel"
        mkdir -p "$(dirname "$dst")"
        # Replace the symlink to /usr/share/... with our real file.
        rm -f "$dst"
        cp -- "$src" "$dst"
        log "  override: $rel"
    done < <(find "$OVERLAY" -type f -print0)
fi

# --- 6. systemd user units -------------------------------------------------
log "reloading systemd user units"
systemctl --user daemon-reload

# Enable+start dms.service. If we're not in a graphical session yet (e.g.
# bootstrapping from a TTY before first niri launch), `--now` may complain
# about no D-Bus session — that's fine, it'll start with niri.
if systemctl --user enable --now dms.service 2>/tmp/dms-enable.err; then
    log "dms.service enabled and running"
else
    warn "dms.service enable --now had a non-fatal hiccup (often: no graphical"
    warn "session yet). Re-run \`systemctl --user enable --now dms.service\`"
    warn "after logging into niri. stderr: $(cat /tmp/dms-enable.err)"
fi

cat <<EOF

[bootstrap] done.

next steps:
  1. log out, then pick "niri" at the display manager
  2. if first launch shows no monitors configured, open DMS settings:
       Mod+Shift+S  (or:  dms ipc call settings open)
       → Display tab → Save
     this regenerates ~/.config/niri/dms/outputs.kdl for your hardware
  3. backups of any pre-existing files are at:
       $BACKUP_DIR

EOF
