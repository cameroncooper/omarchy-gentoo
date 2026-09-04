#!/bin/bash
# Shared harness configuration. Source from other scripts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export OMARCHY_GENTOO_ROOT="$ROOT"

STATE="$ROOT/.state"
ARTIFACTS="$STATE/artifacts"
VM_DIR="$STATE/vm"
SSH_DIR="$STATE/ssh"
LOG_DIR="$STATE/logs"
SEED_DIR="$STATE/seed"
HARNESS="$ROOT/scripts/qemu"

# QEMU / firmware
QEMU_BIN="${QEMU_BIN:-$(command -v qemu-system-aarch64)}"
QEMU_IMG="${QEMU_IMG:-$(command -v qemu-img)}"
EDK2_CODE="${EDK2_CODE:-/opt/homebrew/share/qemu/edk2-aarch64-code.fd}"
EDK2_VARS_SRC="${EDK2_VARS_SRC:-/opt/homebrew/share/qemu/edk2-arm-vars.fd}"

# VM sizing — keep small; grow later if Phase B needs it
DISK_SIZE_GB="${DISK_SIZE_GB:-20}"
SMP="${SMP:-4}"
MEM_MB="${MEM_MB:-6144}"
SSH_PORT="${SSH_PORT:-2222}"
HTTP_PORT="${HTTP_PORT:-8765}"

# Guest identity
HOSTNAME="${HOSTNAME_GUEST:-omarchy-gentoo}"
GUEST_USER="${GUEST_USER:-cameron}"

# Pinned Gentoo artifacts (update together)
GENTOO_BUILD="${GENTOO_BUILD:-20260830T234553Z}"
GENTOO_MIRROR="${GENTOO_MIRROR:-https://distfiles.gentoo.org/releases/arm64/autobuilds}"
STAGE3_NAME="stage3-arm64-systemd-${GENTOO_BUILD}.tar.xz"
ISO_NAME="install-arm64-minimal-${GENTOO_BUILD}.iso"
STAGE3_URL="${GENTOO_MIRROR}/${GENTOO_BUILD}/${STAGE3_NAME}"
ISO_URL="${GENTOO_MIRROR}/${GENTOO_BUILD}/${ISO_NAME}"

# Local artifact filenames (stable names inside state/artifacts)
STAGE3_LOCAL="$ARTIFACTS/stage3-arm64-systemd.tar.xz"
ISO_LOCAL="$ARTIFACTS/install-arm64-minimal.iso"

# VM files
DISK_IMG="$VM_DIR/disk.qcow2"
VARS_FD="$VM_DIR/edk2-vars.fd"
SEED_ISO="$SEED_DIR/seed.iso"
PIDFILE="$VM_DIR/qemu.pid"
SERIAL_LOG="$LOG_DIR/serial.log"
MONITOR_SOCK="$VM_DIR/monitor.sock"
PHASE_A_MARKER="/.omarchy-gentoo-phase-a-complete"

BINHOST_URI="${BINHOST_URI:-https://distfiles.gentoo.org/releases/arm64/binpackages/23.0/arm64/}"

ssh_key() {
  echo "$SSH_DIR/id_ed25519"
}

ssh_pubkey() {
  echo "$SSH_DIR/id_ed25519.pub"
}

ensure_dirs() {
  mkdir -p "$ARTIFACTS" "$VM_DIR" "$SSH_DIR" "$LOG_DIR" "$SEED_DIR"
}
