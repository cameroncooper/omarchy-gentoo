#!/bin/bash
# Install the same overlay package a real Gentoo user selects.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

log "emerge gui-apps/omarchy-desktop from local overlay"
sudo emerge --ask=n --verbose=n --quiet-build=y \
  --autounmask=y --autounmask-write=y --autounmask-continue=y \
  --autounmask-use=y \
  gui-apps/omarchy-desktop

if have_cmd etc-update; then
  sudo etc-update --automode -5 || true
fi

log "initialize current user without replacing custom files"
omarchy-user-init --if-needed

log "enable seat and user-service prerequisites"
sudo systemctl enable seatd.service 2>/dev/null || true
sudo loginctl enable-linger "$(id -un)" || true

log "overlay packages installed"
