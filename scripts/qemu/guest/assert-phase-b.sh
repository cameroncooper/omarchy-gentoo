#!/bin/bash
# Assert runtime prerequisites before the deeper packaged-tree checks.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

log "assert installation marker and core runtime"
[[ -f $PHASE_B_MARKER ]] || die "missing $PHASE_B_MARKER"
have_cmd Hyprland || die "Hyprland missing"
have_cmd quickshell || die "Quickshell missing"
have_cmd foot || die "Foot terminal missing"
have_cmd pipewire || die "PipeWire missing"
have_cmd omarchy-user-init || die "Gentoo integration package missing"
[[ -d /usr/share/omarchy/default/hypr ]] || die "packaged Omarchy tree missing"

log "assert upstream Hyprland user entrypoint"
[[ -s $HOME/.config/hypr/hyprland.lua ]] || die "missing hyprland.lua"
grep -q '/usr/share/omarchy' "$HOME/.config/hypr/hyprland.lua" \
  || grep -q 'OMARCHY_PATH' "$HOME/.config/hypr/hyprland.lua" \
  || die "hyprland.lua does not load packaged Omarchy"
[[ ! -e $HOME/.config/hypr/hyprland.conf ]] \
  || die "legacy hyprland.conf shadows the Lua config"

log "PHASE_B_ASSERT_OK"
