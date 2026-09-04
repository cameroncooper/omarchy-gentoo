#!/bin/bash
# Grow root filesystem if the virtual disk was resized (e.g. 20G → 40G).
# Phase A may lack parted/sgdisk — prefer sfdisk (usually in util-linux).
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

log "check for growable root partition"
ROOT_SRC=$(findmnt -no SOURCE /)
ROOT_SRC=$(readlink -f "$ROOT_SRC")
DISK=$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | head -1 || true)
PARTNUM=$(cat "/sys/class/block/$(basename "$ROOT_SRC")/partition" 2>/dev/null || true)

if [[ -z "$DISK" || -z "$PARTNUM" ]]; then
  warn "could not determine disk/partition for $ROOT_SRC; skipping grow"
  df -h /
  exit 0
fi

DISK_PATH="/dev/$DISK"
log "root=$ROOT_SRC disk=$DISK_PATH part=$PARTNUM"
lsblk -b "$DISK_PATH" || true

if have_cmd sfdisk; then
  # Expand partition N to the end of the disk (", +" = start unchanged, size = max)
  echo ", +" | sudo sfdisk -N "$PARTNUM" --no-reread "$DISK_PATH" || warn "sfdisk resize failed"
elif have_cmd sgdisk && have_cmd parted; then
  sudo sgdisk -e "$DISK_PATH" || true
  sudo parted -s "$DISK_PATH" resizepart "$PARTNUM" 100% || warn "parted resize failed"
else
  warn "no sfdisk/parted available; cannot grow partition"
  df -h /
  exit 0
fi

if have_cmd partx; then
  sudo partx -u "$DISK_PATH" || true
fi
sudo blockdev --rereadpt "$DISK_PATH" 2>/dev/null || true
sleep 1

if have_cmd resize2fs; then
  sudo resize2fs "$ROOT_SRC" || warn "resize2fs failed"
fi

df -h /
log "disk grow step done"
