#!/bin/bash
# Deterministic Phase A: fetch → create → seed → HTTP → expect(livecd autoinstall) → boot → SSH assert
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/config.sh"
ensure_dirs

RESET=0
SKIP_FETCH=0
for arg in "$@"; do
  case "$arg" in
    --reset) RESET=1 ;;
    --skip-fetch) SKIP_FETCH=1 ;;
    -h|--help)
      echo "usage: $0 [--reset] [--skip-fetch]"
      exit 0
      ;;
  esac
done

cd "$ROOT"

if [[ "$RESET" == 1 ]]; then
  echo "==> reset: stopping VM and wiping disk/vars"
  "$HARNESS/vm.sh" stop || true
  rm -f "$DISK_IMG" "$VARS_FD" "$PIDFILE"
fi

if [[ "$SKIP_FETCH" != 1 ]]; then
  echo "==> fetch artifacts"
  "$HARNESS/fetch-artifacts.sh"
fi

echo "==> create vm scaffolding"
"$HARNESS/create-vm.sh"

echo "==> build seed ISO"
"$HARNESS/build-seed.sh"

# Local HTTP server so the guest can wget stage3 from 10.0.2.2
HTTP_PIDFILE="$VM_DIR/http.pid"
stop_http() {
  if [[ -f "$HTTP_PIDFILE" ]]; then
    kill "$(cat "$HTTP_PIDFILE")" 2>/dev/null || true
    rm -f "$HTTP_PIDFILE"
  fi
  if [[ -n "${HTTP_PID:-}" ]]; then
    kill "$HTTP_PID" 2>/dev/null || true
  fi
}
trap 'stop_http' EXIT

stop_http
# Prefer python http.server bound to all interfaces (QEMU user-net reaches host via 10.0.2.2)
(
  cd "$ARTIFACTS"
  exec python3 -m http.server "$HTTP_PORT" --bind 0.0.0.0
) >"$LOG_DIR/http.log" 2>&1 &
HTTP_PID=$!
echo "$HTTP_PID" > "$HTTP_PIDFILE"
sleep 1
if ! kill -0 "$HTTP_PID" 2>/dev/null; then
  echo "FATAL: http server failed; see $LOG_DIR/http.log" >&2
  exit 1
fi
echo "==> http://127.0.0.1:$HTTP_PORT/ serving $ARTIFACTS (pid $HTTP_PID)"

# Build qemu argv file (NUL-separated) for expect
ARGFILE="$VM_DIR/qemu-install.args"
: > "$ARGFILE"
write_arg() {
  printf '%s\0' "$1" >> "$ARGFILE"
}

write_arg "$QEMU_BIN"
for a in -accel hvf -cpu host -smp "$SMP" -m "$MEM_MB" -M virt,highmem=on; do
  write_arg "$a"
done
write_arg "-drive"; write_arg "if=pflash,format=raw,unit=0,readonly=on,file=$EDK2_CODE"
write_arg "-drive"; write_arg "if=pflash,format=raw,unit=1,file=$VARS_FD"

# Main disk
write_arg "-drive"; write_arg "if=virtio,file=$DISK_IMG,format=qcow2,discard=unmap,detect-zeroes=unmap"

# Install ISO as scsi-cd bootindex 0
write_arg "-device"; write_arg "virtio-scsi-pci,id=scsi0"
write_arg "-drive"; write_arg "if=none,id=cd-install,file=$ISO_LOCAL,format=raw,readonly=on,media=cdrom"
write_arg "-device"; write_arg "scsi-cd,bus=scsi0.0,drive=cd-install,bootindex=0"

# Seed ISO as second scsi-cd
write_arg "-drive"; write_arg "if=none,id=cd-seed,file=$SEED_ISO,format=raw,readonly=on,media=cdrom"
write_arg "-device"; write_arg "scsi-cd,bus=scsi0.0,drive=cd-seed"

# Net + rng + serial console
write_arg "-device"; write_arg "virtio-net-pci,netdev=net0"
write_arg "-netdev"; write_arg "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
write_arg "-device"; write_arg "virtio-rng-pci"
write_arg "-nographic"

echo "==> launching installer via expect (serial log: $LOG_DIR/phase-a-serial.log)"
"$HARNESS/vm.sh" stop >/dev/null 2>&1 || true
chmod +x "$HARNESS/phase-a-expect.tcl"
expect "$HARNESS/phase-a-expect.tcl" "$ARGFILE" "$LOG_DIR/phase-a-serial.log"

echo "==> installer finished; booting disk-only"
sleep 2
"$HARNESS/vm.sh" start

echo "==> waiting for SSH on port $SSH_PORT"
ok=0
for i in $(seq 1 90); do
  if "$HARNESS/vm.sh" ssh "echo phase-a-ssh-ok && test -f $PHASE_A_MARKER && df -h /" 2>/dev/null; then
    ok=1
    break
  fi
  sleep 5
  printf '.'
done
echo
if [[ "$ok" != 1 ]]; then
  echo "FATAL: SSH did not come up. Serial tail:" >&2
  tail -n 80 "$SERIAL_LOG" >&2 || tail -n 80 "$LOG_DIR/phase-a-serial.log" >&2 || true
  exit 1
fi

echo "==> running asserts"
"$HARNESS/assert-phase-a.sh"

# Snapshot golden phase-a
GOLDEN="$VM_DIR/disk-phase-a-golden.qcow2"
"$HARNESS/vm.sh" stop
"$QEMU_IMG" convert -O qcow2 -c "$DISK_IMG" "$GOLDEN"
# Keep working disk as a backing-friendly copy
echo "==> golden snapshot: $GOLDEN"
echo "PHASE_A_READY"
