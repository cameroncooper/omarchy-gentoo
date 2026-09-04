#!/bin/bash
# VM validation driver for the real omarchy-gentoo Portage repository.
# Assumes Phase A (systemd Gentoo + sudo + Portage/binhost).
#
# Usage (on the guest): ./scripts/qemu/guest/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      echo "usage: $0"
      exit 0
      ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

log "Omarchy-Gentoo package installation starting"

run_stage() {
  local stage="$1"
  log "stage $(basename "$stage")"
  # shellcheck disable=SC1090
  bash "$stage"
}

run_stage "$ROOT/stages/00-assert-phase-a.sh"
run_stage "$ROOT/stages/05-grow-root.sh"
run_stage "$ROOT/stages/10-portage-overlay.sh"
run_stage "$ROOT/stages/15-local-repository.sh"
run_stage "$ROOT/stages/20-packages.sh"

sudo touch "$PHASE_B_MARKER"
sudo touch "${DESKTOP_MARKER:-/.omarchy-gentoo-desktop-complete}"
cat << EOF | sudo tee /etc/omarchy-gentoo-desktop.txt >/dev/null
completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
user=$(id -un)
hyprland=$(command -v Hyprland || true)
quickshell=$(command -v quickshell || true)
terminal=$(command -v foot || command -v alacritty || true)
omarchy_path=/usr/share/omarchy
EOF

log "DESKTOP_INSTALL_COMPLETE"
echo "Initialize this user with: omarchy-user-init"
echo "Start the desktop with: omarchy-gentoo-session"
