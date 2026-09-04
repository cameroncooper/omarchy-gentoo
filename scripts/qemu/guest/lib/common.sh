#!/bin/bash
# Shared VM validation helpers (sourced by install.sh and stages).
# shellcheck disable=SC2034

PHASE_B_MARKER="${PHASE_B_MARKER:-/.omarchy-gentoo-phase-b-complete}"
PHASE_A_MARKER="${PHASE_A_MARKER:-/.omarchy-gentoo-phase-a-complete}"
DESKTOP_MARKER="${DESKTOP_MARKER:-/.omarchy-gentoo-desktop-complete}"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

emerge_quiet() {
  sudo emerge --ask=n --verbose=n --quiet-build=y "$@"
}
