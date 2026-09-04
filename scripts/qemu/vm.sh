#!/bin/bash
# QEMU HVF VM lifecycle: start | start-gui | stop | status | ssh | serial
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/config.sh"
ensure_dirs

cmd="${1:-status}"
shift || true

DISPLAY_MODE="${DISPLAY_MODE:-none}" # none | cocoa
GUI_XRES="${GUI_XRES:-1280}"
# AArch64 EDK2's text console needs enough height for at least 25 rows.
# 800px can select a GOP mode that trips GraphicsConsoleDxe on warm reboot.
GUI_YRES="${GUI_YRES:-900}"

qemu_running() {
  if [[ -f "$PIDFILE" ]]; then
    local pid
    pid=$(cat "$PIDFILE" 2>/dev/null || true)
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

# Build QEMU argv into global array QEMU_ARGS
build_base_args() {
  QEMU_ARGS=(
    -accel hvf
    -cpu host
    -smp "$SMP"
    -m "$MEM_MB"
    -M virt,highmem=on
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=$EDK2_CODE"
    -drive "if=pflash,format=raw,unit=1,file=$VARS_FD"
    -device virtio-net-pci,netdev=net0
    -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
    -device virtio-rng-pci
  )

  if [[ "$DISPLAY_MODE" == "cocoa" ]]; then
    # Visible macOS window + virtio-gpu DRM device for Wayland/Hyprland
    QEMU_ARGS+=(
      -device "virtio-gpu-pci,xres=${GUI_XRES},yres=${GUI_YRES}"
      -display cocoa,zoom-to-fit=on
      -device qemu-xhci
      -device usb-kbd
      -device usb-tablet
    )
  else
    QEMU_ARGS+=(-display none)
  fi
}

start_disk_only() {
  if qemu_running; then
    echo "already running (pid $(cat "$PIDFILE"))"
    return 0
  fi
  rm -f "$PIDFILE" "$MONITOR_SOCK"
  [[ -f "$DISK_IMG" ]] || { echo "missing disk; run create-vm.sh / phase-a"; exit 1; }

  build_base_args
  QEMU_ARGS+=(
    -drive "if=virtio,file=$DISK_IMG,format=qcow2,discard=unmap,detect-zeroes=unmap"
    -serial "file:$SERIAL_LOG"
    -monitor "unix:$MONITOR_SOCK,server,nowait"
  )

  : > "$SERIAL_LOG"
  # nohup + setsid-ish: keep QEMU alive after the launching shell exits
  nohup "$QEMU_BIN" "${QEMU_ARGS[@]}" >"$LOG_DIR/qemu-stdout.log" 2>&1 &
  local pid=$!
  echo "$pid" > "$PIDFILE"
  disown "$pid" 2>/dev/null || true
  sleep 1
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "FATAL: qemu exited immediately; see $LOG_DIR/qemu-stdout.log" >&2
    cat "$LOG_DIR/qemu-stdout.log" >&2 || true
    rm -f "$PIDFILE"
    exit 1
  fi
  if [[ "$DISPLAY_MODE" == "cocoa" ]]; then
    echo "started pid $pid  GUI=cocoa  ssh: localhost:$SSH_PORT"
  else
    echo "started pid $pid  ssh: localhost:$SSH_PORT  serial: $SERIAL_LOG"
  fi
}

stop_vm() {
  if ! qemu_running; then
    echo "not running"
    rm -f "$PIDFILE"
    return 0
  fi
  local pid
  pid=$(cat "$PIDFILE")
  echo "stopping $pid"
  if [[ -S "$MONITOR_SOCK" ]]; then
    printf 'system_powerdown\n' | nc -U "$MONITOR_SOCK" >/dev/null 2>&1 || true
    for _ in $(seq 1 15); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
  fi
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    sleep 1
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$PIDFILE" "$MONITOR_SOCK"
  echo "stopped"
}

ssh_vm() {
  local key
  key=$(ssh_key)
  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o GlobalKnownHostsFile=/dev/null \
      -o ConnectTimeout=5 \
      -i "$key" \
      -p "$SSH_PORT" \
      "${GUEST_USER}@127.0.0.1" "$@"
}

case "$cmd" in
  start)
    DISPLAY_MODE=none
    start_disk_only
    ;;
  start-gui|gui)
    DISPLAY_MODE=cocoa
    start_disk_only
    ;;
  stop) stop_vm ;;
  status)
    if qemu_running; then
      echo "running pid=$(cat "$PIDFILE") ssh_port=$SSH_PORT"
    else
      echo "stopped"
      rm -f "$PIDFILE"
    fi
    ;;
  ssh) ssh_vm "$@" ;;
  serial) exec tail -f "$SERIAL_LOG" ;;
  *)
    echo "usage: $0 {start|start-gui|stop|status|ssh|serial}" >&2
    exit 1
    ;;
esac
