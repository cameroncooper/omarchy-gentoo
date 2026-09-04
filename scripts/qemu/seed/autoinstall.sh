#!/bin/bash
# Runs on the Gentoo livecd. Partitions the virtio disk, extracts stage3,
# configures a minimal systemd + SSH system, copies the livecd kernel
# (no arm64 kernel binpkgs; keeps 20G feasible), installs GRUB, poweroffs.
set -euo pipefail

fail() {
  echo "PHASE_A_INSTALL_FAILED: $*" >&2
  exit 1
}

trap 'echo "PHASE_A_INSTALL_FAILED: line $LINENO exit $?" >&2' ERR

if [[ -f /mnt/seed/install.env ]]; then
  # shellcheck disable=SC1091
  source /mnt/seed/install.env
elif [[ -f /seed/install.env ]]; then
  # shellcheck disable=SC1091
  source /seed/install.env
else
  fail "install.env not found (seed not mounted?)"
fi

HOSTNAME="${HOSTNAME:-omarchy-gentoo}"
GUEST_USER="${GUEST_USER:-cameron}"
HTTP_PORT="${HTTP_PORT:-8765}"
STAGE3_FILE="${STAGE3_FILE:-stage3-arm64-systemd.tar.xz}"
BINHOST_URI="${BINHOST_URI:-https://distfiles.gentoo.org/releases/arm64/binpackages/23.0/arm64/}"
PHASE_A_MARKER="${PHASE_A_MARKER:-/.omarchy-gentoo-phase-a-complete}"

echo "==> network (livecd)"
if ! ping -c1 -W2 10.0.2.2 >/dev/null 2>&1; then
  dhcpcd -q || systemctl start dhcpcd.service 2>/dev/null || true
  sleep 2
fi
# Host HTTP reachability (stage3)
for i in 1 2 3 4 5 6 7 8 9 10; do
  if wget -q -O /dev/null "http://10.0.2.2:${HTTP_PORT}/" 2>/dev/null \
    || curl -sf -o /dev/null "http://10.0.2.2:${HTTP_PORT}/" 2>/dev/null; then
    break
  fi
  echo "waiting for host http (try $i)..."
  sleep 2
done

DISK=""
# Prefer the large writable virtio disk; skip sr* and small seed devices
while read -r name size; do
  case "$name" in
    vd*|sd*|nvme*)
      # > 2G => candidate root disk (20G target)
      if [[ "$size" -gt 2000000000 ]]; then
        DISK="/dev/$name"
        break
      fi
      ;;
  esac
done < <(lsblk -b -dn -o NAME,SIZE 2>/dev/null || true)
if [[ -z "$DISK" ]]; then
  for cand in /dev/vda /dev/sda /dev/nvme0n1; do
    if [[ -b "$cand" ]]; then DISK="$cand"; break; fi
  done
fi
if [[ -z "$DISK" ]]; then
  echo "FATAL: no target disk found" >&2
  lsblk >&2 || true
  exit 1
fi

echo "==> target disk: $DISK"
echo "==> wiping partition table"
wipefs -a "$DISK" || true
sgdisk --zap-all "$DISK" || true

# 512M ESP + rest root (no swap — save space on 20G)
echo "==> partitioning"
sgdisk -n 1:0:+512M -t 1:EF00 -c 1:EFI "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:root "$DISK"
partprobe "$DISK" || true
sleep 2

if [[ -b "${DISK}p1" ]]; then
  EFI="${DISK}p1"
  ROOT="${DISK}p2"
else
  EFI="${DISK}1"
  ROOT="${DISK}2"
fi

echo "==> formatting $EFI (ESP) and $ROOT (ext4)"
mkfs.vfat -F32 -n EFI "$EFI"
mkfs.ext4 -F -L root "$ROOT"

echo "==> mounting"
mkdir -p /mnt/gentoo
mount "$ROOT" /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount "$EFI" /mnt/gentoo/boot/efi

echo "==> fetching stage3 from host (10.0.2.2:${HTTP_PORT})"
HOST_URL="http://10.0.2.2:${HTTP_PORT}/${STAGE3_FILE}"
cd /mnt/gentoo
for i in 1 2 3 4 5 6 7 8 9 10; do
  if command -v curl >/dev/null; then
    curl -fL --retry 3 -o stage3.tar.xz "$HOST_URL" && break
  else
    wget -O stage3.tar.xz "$HOST_URL" && break
  fi
  echo "stage3 download retry $i..."
  sleep 3
done
[[ -s stage3.tar.xz ]] || { echo "FATAL: stage3 download failed"; exit 1; }

echo "==> extracting stage3"
tar xpf stage3.tar.xz --xattrs-include='*.*' --numeric-owner
rm -f stage3.tar.xz

echo "==> fstab"
cat > /mnt/gentoo/etc/fstab << EOF
LABEL=root  /          ext4  noatime,errors=remount-ro  0 1
LABEL=EFI   /boot/efi  vfat  umask=0077                 0 2
EOF

echo "==> make.conf (space-conscious + binhost-friendly)"
cat > /mnt/gentoo/etc/portage/make.conf << EOF
COMMON_FLAGS="-O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"
MAKEOPTS="-j3 -l4"
EMERGE_DEFAULT_OPTS="--jobs=2 --load-average=4 --quiet-build=y --with-bdeps=y"
FEATURES="parallel-fetch getbinpkg binpkg-request-signature"
ACCEPT_KEYWORDS="arm64"
GRUB_PLATFORMS="efi-64"
VIDEO_CARDS=""
INPUT_DEVICES=""
# Keep portage scratch small-ish; clean aggressively after emerges
PORTAGE_TMPDIR="/var/tmp"
EOF

mkdir -p /mnt/gentoo/etc/portage/binrepos.conf
cat > /mnt/gentoo/etc/portage/binrepos.conf/gentoobinhost.conf << EOF
[gentoo]
priority = 9999
sync-uri = ${BINHOST_URI}
verify-signature = true
EOF

echo "==> hostname / timezone / locale"
echo "$HOSTNAME" > /mnt/gentoo/etc/hostname
ln -sf /usr/share/zoneinfo/UTC /mnt/gentoo/etc/localtime
echo "en_US.UTF-8 UTF-8" > /mnt/gentoo/etc/locale.gen
cat > /mnt/gentoo/etc/locale.conf << EOF
LANG=en_US.UTF-8
EOF

echo "==> systemd-networkd DHCP"
mkdir -p /mnt/gentoo/etc/systemd/network
cat > /mnt/gentoo/etc/systemd/network/20-virtio.network << EOF
[Match]
Name=en*
Name=eth*
Name=ens*
Name=ven*
Name=var*

[Network]
DHCP=yes

[DHCP]
ClientIdentifier=mac
EOF

# resolv stub
ln -sf /run/systemd/resolve/resolv.conf /mnt/gentoo/etc/resolv.conf || true

echo "==> copy DNS for chroot"
# stage3 ships resolv.conf as a dangling symlink to systemd-resolved; replace it
rm -f /mnt/gentoo/etc/resolv.conf
if [[ -e /etc/resolv.conf ]]; then
  cp -L /etc/resolv.conf /mnt/gentoo/etc/resolv.conf || \
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /mnt/gentoo/etc/resolv.conf
else
  printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /mnt/gentoo/etc/resolv.conf
fi

echo "==> bind mounts for chroot"
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

# Authorized keys for guest user
mkdir -p /mnt/gentoo/root/seed
cp /mnt/seed/authorized_keys /mnt/gentoo/root/seed/authorized_keys

echo "==> chroot: locale, packages, user, bootloader"
cat > /mnt/gentoo/root/chroot-phase-a.sh << 'CHROOT'
#!/bin/bash
set -eo pipefail
# Intentionally not using nounset: /etc/profile and portage hooks assume unbound-ok
GUEST_USER="${GUEST_USER:-cameron}"
HOSTNAME="${HOSTNAME:-omarchy-gentoo}"
if [[ -f /root/seed/install.env ]]; then
  # shellcheck disable=SC1091
  set -a
  source /root/seed/install.env
  set +a
fi
GUEST_USER="${GUEST_USER:-cameron}"
HOSTNAME="${HOSTNAME:-omarchy-gentoo}"

mkdir -p /var/db/repos/gentoo /etc/portage/repos.conf
# Ensure gentoo repo location exists before any portage query
if [[ ! -f /etc/portage/repos.conf/gentoo.conf ]]; then
  cat > /etc/portage/repos.conf/gentoo.conf << EOF
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = webrsync
auto-sync = yes
EOF
fi

echo "==> sync portage tree"
if ! emerge-webrsync; then
  echo "webrsync failed; trying emerge --sync"
  emerge --sync
fi

locale-gen
eselect locale set en_US.utf8 || true
# shellcheck disable=SC1091
source /etc/profile || true
env-update || true
# shellcheck disable=SC1091
source /etc/profile || true

echo "==> installing packages (prefer binpkgs)"
# Kernel: intentionally NOT emerged — livecd kernel is copied outside chroot.
emerge --ask=n --verbose=n \
  sys-boot/grub \
  net-misc/openssh \
  app-admin/sudo \
  app-editors/nano \
  app-portage/gentoolkit

echo "==> enable services"
systemctl enable sshd.service
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

echo "==> root password locked (SSH keys only)"
passwd -l root || true

echo "==> create user $GUEST_USER"
if ! id "$GUEST_USER" &>/dev/null; then
  useradd -m -G wheel,users -s /bin/bash "$GUEST_USER"
fi
mkdir -p "/home/$GUEST_USER/.ssh"
chmod 700 "/home/$GUEST_USER/.ssh"
cp /root/seed/authorized_keys "/home/$GUEST_USER/.ssh/authorized_keys"
chmod 600 "/home/$GUEST_USER/.ssh/authorized_keys"
chown -R "$GUEST_USER:$GUEST_USER" "/home/$GUEST_USER/.ssh"
mkdir -p /etc/sudoers.d
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-harness.conf << EOF
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF

echo "==> GRUB install"
grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=Gentoo --recheck
mkdir -p /boot/efi/EFI/BOOT
if [[ -f /boot/efi/EFI/Gentoo/grubaa64.efi ]]; then
  cp /boot/efi/EFI/Gentoo/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI
fi

KVER=$(ls -1 /lib/modules | head -1 || true)
if [[ -z "$KVER" ]]; then
  echo "FATAL: no modules under /lib/modules" >&2
  exit 1
fi

cat > /etc/default/grub << EOF
GRUB_DISTRIBUTOR="Gentoo"
GRUB_DEFAULT=0
GRUB_TIMEOUT=2
GRUB_CMDLINE_LINUX="root=LABEL=root rootfstype=ext4 console=ttyAMA0,115200n8 rw"
GRUB_TERMINAL="serial console"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200"
EOF

grub-mkconfig -o /boot/grub/grub.cfg

rm -rf /var/cache/distfiles/* /var/tmp/portage/* /var/cache/binpkgs/* 2>/dev/null || true
eclean-dist -d 2>/dev/null || true

df -h /
echo "chroot phase-a packages done"
CHROOT

# Pass install.env into chroot seed
cp /mnt/seed/install.env /mnt/gentoo/root/seed/install.env
chmod +x /mnt/gentoo/root/chroot-phase-a.sh

echo "==> copy livecd kernel + modules (no arm64 kernel binpkg)"
KVER="$(uname -r)"
mkdir -p /mnt/gentoo/lib/modules
if [[ -d "/lib/modules/$KVER" ]]; then
  cp -a "/lib/modules/$KVER" /mnt/gentoo/lib/modules/
else
  fail "missing /lib/modules/$KVER"
fi

# Mount install ISO if needed and hunt for the kernel/initramfs the livecd booted
mkdir -p /mnt/cdrom
if ! mountpoint -q /mnt/cdrom; then
  for d in /dev/sr0 /dev/sr1 /dev/cdrom; do
    if [[ -e "$d" ]]; then
      mount -o ro "$d" /mnt/cdrom 2>/dev/null && break || true
    fi
  done
fi

mkdir -p /mnt/gentoo/boot
shopt -s nullglob
# Collect candidate kernel/initrd paths from common livecd locations
CAND_KERNELS=()
CAND_INITRDS=()
for dir in /boot /mnt/cdrom/boot /mnt/cdrom /mnt/livecd/boot /run/rootfsbase/boot /lib/modules/"$KVER"; do
  [[ -d "$dir" ]] || continue
  for f in "$dir"/vmlinuz* "$dir"/kernel* "$dir"/Image* "$dir"/gentoo "$dir"/gentoo-*; do
    [[ -f "$f" ]] || continue
    case "$f" in
      *.igz|*.img|*.gz) continue ;;
    esac
    # skip obvious initramfs names
    case "$(basename "$f")" in
      initramfs*|initrd*) continue ;;
    esac
    CAND_KERNELS+=("$f")
  done
  for f in "$dir"/initramfs* "$dir"/initrd* "$dir"/*.igz "$dir"/gentoo.igz; do
    [[ -f "$f" ]] || continue
    CAND_INITRDS+=("$f")
  done
done

echo "kernel candidates: ${CAND_KERNELS[*]:-none}"
echo "initrd candidates: ${CAND_INITRDS[*]:-none}"
ls -la /boot /mnt/cdrom/boot 2>/dev/null || true
ls -la /lib/modules/"$KVER" | head -20 || true

KERNEL_SRC=""
# Prefer kernel bundled in the seed ISO (host-extracted, deterministic)
if [[ -s /mnt/seed/boot/gentoo ]]; then
  KERNEL_SRC=/mnt/seed/boot/gentoo
fi
if [[ -z "$KERNEL_SRC" ]]; then
  for f in "${CAND_KERNELS[@]:-}"; do
    case "$(basename "$f")" in
      *"$KVER"*|vmlinuz|gentoo|Image|kernel)
        KERNEL_SRC="$f"
        break
        ;;
    esac
  done
fi
if [[ -z "$KERNEL_SRC" && ${#CAND_KERNELS[@]} -gt 0 ]]; then
  KERNEL_SRC="${CAND_KERNELS[0]}"
fi
[[ -n "$KERNEL_SRC" ]] || fail "could not locate livecd kernel image"

cp -a "$KERNEL_SRC" "/mnt/gentoo/boot/vmlinuz-$KVER"
ln -sfn "vmlinuz-$KVER" /mnt/gentoo/boot/vmlinuz

INITRD_SRC=""
if [[ -s /mnt/seed/boot/gentoo.igz ]]; then
  INITRD_SRC=/mnt/seed/boot/gentoo.igz
fi
if [[ -z "$INITRD_SRC" ]]; then
  for f in "${CAND_INITRDS[@]:-}"; do
    case "$(basename "$f")" in
      *"$KVER"*|initramfs*|initrd*|gentoo.igz|*.igz)
        INITRD_SRC="$f"
        break
        ;;
    esac
  done
fi
if [[ -z "$INITRD_SRC" && ${#CAND_INITRDS[@]} -gt 0 ]]; then
  INITRD_SRC="${CAND_INITRDS[0]}"
fi
if [[ -n "$INITRD_SRC" ]]; then
  cp -a "$INITRD_SRC" "/mnt/gentoo/boot/initramfs-$KVER.img"
  ln -sfn "initramfs-$KVER.img" /mnt/gentoo/boot/initramfs.img
else
  echo "WARN: no initramfs found; hoping virtio is built-in"
fi

# Optional System.map
if [[ -s /mnt/seed/boot/System-gentoo.map ]]; then
  cp -a /mnt/seed/boot/System-gentoo.map "/mnt/gentoo/boot/System.map-$KVER"
fi

ls -la /mnt/gentoo/boot
file "/mnt/gentoo/boot/vmlinuz-$KVER" || true

echo "==> run chroot script"
chroot /mnt/gentoo /bin/bash /root/chroot-phase-a.sh

echo "==> mark phase-a complete"
touch "/mnt/gentoo${PHASE_A_MARKER}"
cat > /mnt/gentoo/etc/omarchy-gentoo-phase-a.txt << EOF
completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
kernel=$KVER
hostname=$HOSTNAME
user=$GUEST_USER
disk=$DISK
EOF

echo "==> unmount and poweroff"
sync
umount -R /mnt/gentoo || true
echo "PHASE_A_INSTALL_COMPLETE"
poweroff -f
