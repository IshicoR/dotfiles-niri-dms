#!/usr/bin/env bash
# refresh-dms-overlay.sh — re-link the quickshell/dms overlay after a DMS upgrade.
#
# Background: the overlay at ~/.config/quickshell/dms/ is a `cp -as` mirror of
# /usr/share/quickshell/dms/. When DMS ships new QML files in an upgrade, the
# system tree gains files that aren't yet in the mirror, and DMS fails to load
# them (typical symptom: "<NewType> is not a type", dms.service restart loop).
#
# This script finds those missing files and creates symlinks for them, without
# touching any locally-overridden real files in the mirror.

set -euo pipefail

SYS=/usr/share/quickshell/dms
USR="$HOME/.config/quickshell/dms"

[ -d "$SYS" ] || { echo "error: $SYS not found" >&2; exit 1; }
[ -d "$USR" ] || { echo "error: $USR not found — run bootstrap.sh first" >&2; exit 1; }

missing=$(diff <(cd "$SYS" && find . -type f | sort) \
               <(cd "$USR" && find . \( -type f -o -type l \) | sort) \
            | awk '/^< / {print $2}')

if [ -z "$missing" ]; then
    echo "overlay is up to date — nothing missing"
    exit 0
fi

count=0
while IFS= read -r rel; do
    rel="${rel#./}"
    src="$SYS/$rel"
    dst="$USR/$rel"
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    echo "  linked: $rel"
    count=$((count + 1))
done <<< "$missing"

echo "linked $count new file(s) — restart dms.service to pick them up:"
echo "  systemctl --user restart dms.service"
