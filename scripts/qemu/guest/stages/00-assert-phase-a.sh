#!/bin/bash
# Assert Phase A contract before overlay work.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

log "assert Phase A contract"
[[ -f "$PHASE_A_MARKER" ]] || die "missing Phase A marker ($PHASE_A_MARKER); run Phase A first"
[[ "$(id -u)" != 0 ]] || die "run Phase B as the normal user (with sudo)"
sudo -n true || die "passwordless sudo required"
[[ "$(ps -p 1 -o comm=)" == systemd ]] || die "PID 1 must be systemd"
have_cmd emerge || die "emerge missing"
free_kb=$(df -Pk / | awk 'NR==2{print $4}')
free_gb=$((free_kb / 1024 / 1024))
log "free disk ~${free_gb}G"
if (( free_gb < 8 )); then
  die "need >=8G free for Hyprland compile/desktop (have ~${free_gb}G); grow the disk"
fi
log "Phase A contract OK"
