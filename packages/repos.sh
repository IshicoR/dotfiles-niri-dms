#!/usr/bin/env bash
# Enable the COPRs that provide niri / quickshell / dms.
# Idempotent: re-running is safe.
set -euo pipefail

if ! command -v dnf >/dev/null 2>&1; then
    echo "error: dnf not found — this script targets Fedora." >&2
    exit 1
fi

# RPMFusion (free + nonfree) — provides VLC, ffmpeg-with-codecs, etc.
# Skip nonfree if you don't want NVIDIA / Steam repos enabled.
sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# COPRs
sudo dnf -y copr enable yalter/niri
sudo dnf -y copr enable avengemedia/danklinux
sudo dnf -y copr enable avengemedia/dms

echo "repos: ok"
