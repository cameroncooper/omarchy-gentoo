#!/bin/bash
# Ensure SSH key, disk image, and UEFI vars exist.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/config.sh"
ensure_dirs

if [[ ! -f "$(ssh_key)" ]]; then
  ssh-keygen -t ed25519 -N "" -f "$(ssh_key)" -C "omarchy-gentoo-harness"
  echo "created harness SSH key"
fi

if [[ ! -f "$VARS_FD" ]]; then
  if [[ -f "$EDK2_VARS_SRC" ]]; then
    cp "$EDK2_VARS_SRC" "$VARS_FD"
  else
    # 64MiB empty pflash vars store
    dd if=/dev/zero of="$VARS_FD" bs=1m count=64 status=none
  fi
  echo "created UEFI vars: $VARS_FD"
fi

if [[ ! -f "$DISK_IMG" ]]; then
  "$QEMU_IMG" create -f qcow2 "$DISK_IMG" "${DISK_SIZE_GB}G"
  echo "created disk: $DISK_IMG (${DISK_SIZE_GB}G)"
else
  echo "disk exists: $DISK_IMG"
fi
