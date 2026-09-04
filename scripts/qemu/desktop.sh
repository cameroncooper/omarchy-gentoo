#!/bin/bash
# One desktop overlay: Hyprland + Omarchy tree + Quickshell on a Gentoo base guest.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/config.sh"
ensure_dirs

RESTORE_GOLDEN=0
for arg in "$@"; do
  case "$arg" in
    --from-golden) RESTORE_GOLDEN=1 ;;
    -h|--help)
      echo "usage: $0 [--from-golden]"
      exit 0
      ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

GOLDEN="$VM_DIR/disk-phase-a-golden.qcow2"
DISK_GIB=64

if [[ "$RESTORE_GOLDEN" == 1 ]]; then
  "$HARNESS/vm.sh" stop || true
  [[ -f "$GOLDEN" ]] || { echo "missing golden $GOLDEN"; exit 1; }
  echo "==> restore working disk from Phase A golden"
  rm -f "$DISK_IMG"
  "$QEMU_IMG" convert -O qcow2 "$GOLDEN" "$DISK_IMG"
  "$QEMU_IMG" resize "$DISK_IMG" "${DISK_GIB}G"
fi

CUR=$("$QEMU_IMG" info --output=json "$DISK_IMG" | python3 -c 'import json,sys; print(json.load(sys.stdin)["virtual-size"])')
MIN=$((DISK_GIB * 1024 * 1024 * 1024))
if (( CUR < MIN )); then
  echo "==> resizing disk to ${DISK_GIB}G (Qt6/Quickshell compile)"
  "$HARNESS/vm.sh" stop || true
  "$QEMU_IMG" resize "$DISK_IMG" "${DISK_GIB}G"
fi

echo "==> start VM"
"$HARNESS/vm.sh" start

echo "==> wait for SSH"
ok=0
for _ in $(seq 1 60); do
  if "$HARNESS/vm.sh" ssh "true" 2>/dev/null; then
    ok=1
    break
  fi
  sleep 3
done
[[ "$ok" == 1 ]] || { echo "FATAL: SSH down"; exit 1; }

REMOTE_DIR="/home/${GUEST_USER}/omarchy-gentoo"
echo "==> sync Gentoo repository + VM driver to guest"
"$HARNESS/vm.sh" ssh "mkdir -p $REMOTE_DIR && rm -rf \
  $REMOTE_DIR/dev-qt $REMOTE_DIR/gui-apps $REMOTE_DIR/metadata \
  $REMOTE_DIR/profiles $REMOTE_DIR/scripts $REMOTE_DIR/x11-themes"
tar -C "$ROOT" -czf - \
  dev-qt gui-apps metadata profiles scripts/qemu/guest scripts/tests \
  x11-themes README.md \
  | "$HARNESS/vm.sh" ssh "tar -C $REMOTE_DIR -xzf -"

echo "==> emerge packaged desktop (Hyprland + Quickshell compiles are long)"
GUEST_DRIVER="$REMOTE_DIR/scripts/qemu/guest"
"$HARNESS/vm.sh" ssh "chmod +x $GUEST_DRIVER/install.sh $GUEST_DRIVER/stages/*.sh $GUEST_DRIVER/assert-*.sh && cd $GUEST_DRIVER && ./install.sh"

echo "==> assert desktop"
"$HARNESS/vm.sh" ssh "bash $GUEST_DRIVER/assert-phase-b.sh"
"$HARNESS/vm.sh" ssh "bash $GUEST_DRIVER/assert-desktop.sh"

echo "==> snapshot desktop golden"
"$HARNESS/vm.sh" stop
GOLDEN_D="$VM_DIR/disk-desktop-golden.qcow2"
"$QEMU_IMG" convert -O qcow2 -c "$DISK_IMG" "$GOLDEN_D"
echo "golden: $GOLDEN_D"
echo "DESKTOP_READY"
