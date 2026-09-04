#!/usr/bin/env bash
# Build a small seed ISO: autoinstall script + pubkey + install config.
# Stage3 is served over HTTP from the host (10.0.2.2) — keeps seed tiny.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/config.sh"
ensure_dirs

if [[ ! -f "$(ssh_pubkey)" ]]; then
  echo "missing SSH pubkey; run create-vm.sh first" >&2
  exit 1
fi

STAGE="$SEED_DIR/root"
rm -rf "$STAGE"
mkdir -p "$STAGE"

cp "$HARNESS/seed/autoinstall.sh" "$STAGE/autoinstall.sh"
cp "$(ssh_pubkey)" "$STAGE/authorized_keys"
chmod 755 "$STAGE/autoinstall.sh"

# Extract livecd kernel/initramfs into the seed so the guest does not depend on
# discovering ISO mount layout (deterministic + works offline for that step).
mkdir -p "$STAGE/boot"
xorriso -osirrox on -indev "$ISO_LOCAL" \
  -extract /boot/gentoo "$STAGE/boot/gentoo" \
  -extract /boot/gentoo.igz "$STAGE/boot/gentoo.igz" \
  -extract /boot/System-gentoo.map "$STAGE/boot/System-gentoo.map" \
  2>/dev/null || {
    echo "FATAL: could not extract kernel from $ISO_LOCAL" >&2
    exit 1
  }
[[ -s "$STAGE/boot/gentoo" && -s "$STAGE/boot/gentoo.igz" ]] || {
  echo "FATAL: extracted kernel/initrd missing or empty" >&2
  exit 1
}
echo "seed kernel: $(/usr/bin/stat -f%z "$STAGE/boot/gentoo" 2>/dev/null || /usr/bin/stat -c%s "$STAGE/boot/gentoo") bytes"

cat > "$STAGE/install.env" << EOF
HOSTNAME=$HOSTNAME
GUEST_USER=$GUEST_USER
HTTP_PORT=$HTTP_PORT
STAGE3_FILE=stage3-arm64-systemd.tar.xz
BINHOST_URI=$BINHOST_URI
PHASE_A_MARKER=$PHASE_A_MARKER
DISK_SIZE_GB=$DISK_SIZE_GB
EOF

# Joliet+RockRidge ISO labeled OMGSEED for easy discovery in the livecd
rm -f "$SEED_ISO"
mkisofs -quiet -R -J -V OMGSEED -o "$SEED_ISO" "$STAGE"
sz=$(/usr/bin/stat -f%z "$SEED_ISO" 2>/dev/null || /usr/bin/stat -c%s "$SEED_ISO")
echo "seed ISO: $SEED_ISO ($sz bytes)"
