#!/bin/bash
# Bring up a visible Hyprland session in QEMU (cocoa + virtio-gpu).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/config.sh"
ensure_dirs

echo "==> stop any headless VM"
"$HARNESS/vm.sh" stop || true

echo "==> start GUI VM (cocoa + virtio-gpu)"
"$HARNESS/vm.sh" start-gui

echo "==> wait for SSH"
ok=0
for _ in $(seq 1 60); do
  if "$HARNESS/vm.sh" ssh true 2>/dev/null; then
    ok=1
    break
  fi
  sleep 3
done
[[ "$ok" == 1 ]] || { echo "FATAL: SSH down"; exit 1; }

echo "==> sync repository + verify packaged desktop + qemu-gui"
REMOTE_DIR="/home/${GUEST_USER}/omarchy-gentoo"
"$HARNESS/vm.sh" ssh "mkdir -p $REMOTE_DIR"
tar -C "$ROOT" -czf - \
  dev-qt gui-apps metadata profiles scripts/qemu/guest scripts/tests \
  x11-themes README.md \
  | "$HARNESS/vm.sh" ssh "rm -rf \
      $REMOTE_DIR/dev-qt $REMOTE_DIR/gui-apps $REMOTE_DIR/metadata \
      $REMOTE_DIR/profiles $REMOTE_DIR/scripts $REMOTE_DIR/x11-themes \
      && tar -C $REMOTE_DIR -xzf -"
GUEST_DRIVER="$REMOTE_DIR/scripts/qemu/guest"
"$HARNESS/vm.sh" ssh "chmod +x $GUEST_DRIVER/stages/*.sh $GUEST_DRIVER/assert-*.sh"
"$HARNESS/vm.sh" ssh "bash $GUEST_DRIVER/stages/15-local-repository.sh"
"$HARNESS/vm.sh" ssh "bash $GUEST_DRIVER/assert-desktop.sh"
"$HARNESS/vm.sh" ssh "bash $GUEST_DRIVER/stages/50-qemu-gui.sh"

echo "==> reboot into GUI session (autologin tty1 → Hyprland)"
"$HARNESS/vm.sh" ssh "sudo systemctl reboot" || true
sleep 5

# Wait for SSH again after reboot (Hyprland may be up; sshd should still work)
ok=0
for _ in $(seq 1 90); do
  if "$HARNESS/vm.sh" ssh true 2>/dev/null; then
    ok=1
    break
  fi
  sleep 3
done
[[ "$ok" == 1 ]] || echo "WARN: SSH not back yet — check the cocoa window"

echo "==> session probe"
"$HARNESS/vm.sh" ssh 'echo "wayland=${WAYLAND_DISPLAY:-}"; pgrep -a Hyprland || true; lsmod | grep -i virtio_gpu || true; ls -l /dev/dri 2>/dev/null || true' || true

echo "GUI_READY — QEMU cocoa (Hyprland via omarchy-gentoo-session → /usr/bin/start-hyprland)"
echo "  Expect: upstream Omarchy Quickshell bar. Super+Space = menu"
echo "  QEMU cocoa must deliver a Super key for upstream bindings"
echo "  SSH: ./scripts/qemu/vm.sh ssh"
