#!/bin/bash
# Prepare guest for a visible Hyprland session under QEMU virtio-gpu.
# Idempotent — safe to re-run.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log "emerge Mesa / DRM stack for virtio-gpu (skip if packages are installed)"
# A headless validation boot intentionally has no /dev/dri; using device
# presence here caused Mesa to rebuild every time before switching to GUI.
if ! qlist -IC media-libs/mesa x11-libs/libdrm media-libs/libglvnd >/dev/null 2>&1; then
  sudo mkdir -p /etc/portage/package.use
  if ! grep -q 'VIDEO_CARDS' /etc/portage/make.conf 2>/dev/null; then
    echo 'VIDEO_CARDS="virtio lavapipe"' | sudo tee -a /etc/portage/make.conf >/dev/null
  fi
  cat <<'EOF' | sudo tee /etc/portage/package.use/omarchy-mesa >/dev/null
media-libs/mesa virtio lavapipe opengl gles2 -vaapi -vdpau
x11-libs/libdrm video_cards_virtio
EOF
  emerge_quiet media-libs/libglvnd x11-libs/libdrm media-libs/mesa || \
    sudo emerge --ask=n --verbose=n --quiet-build=y \
      --autounmask=y --autounmask-write=y --autounmask-continue=y \
      media-libs/libglvnd x11-libs/libdrm media-libs/mesa
  sudo etc-update --automode -5 || true
else
  log "virtio-gpu already available — skipping mesa emerge"
fi

# seatd helps non-greeter Wayland sessions; ignore if unit naming differs
if ! systemctl is-enabled seatd.service &>/dev/null && ! systemctl is-enabled seatd &>/dev/null; then
  if emerge_quiet sys-auth/seatd; then
    sudo systemctl enable --now seatd.service 2>/dev/null || \
      sudo systemctl enable --now seatd 2>/dev/null || true
  else
    warn "seatd emerge failed (systemd-logind may still work)"
  fi
fi

log "initialize packaged Omarchy user config"
# This disposable VM may contain files written by the retired subset
# prototype. The migration is signature-gated and backs them up first.
omarchy-user-init --migrate-prototype
install -m 644 "$ROOT/qemu/monitors.lua" "$HOME/.config/hypr/monitors.lua"
install -m 644 "$ROOT/qemu/bindings.lua" "$HOME/.config/hypr/bindings.lua"
# Remove prototype-era binaries that could shadow packaged commands.
rm -f "$HOME/.local/bin/start-hyprland" \
  "$HOME/.local/bin/omarchy-gentoo-session" \
  "$HOME/.local/bin/omarchy-gentoo-launcher" \
  "$HOME/.local/bin/omarchy-gentoo-waybar"

log "tty1 autologin + autostart Omarchy-Gentoo session"
# systemd getty autologin for the graphical VT
USER_NAME="$(id -un)"
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_NAME} --noclear %I \$TERM
EOF
sudo systemctl daemon-reload

# Rewrite tty1 autostart snippets to use omarchy-gentoo-session (not start-hyprland)
rewrite_autostart() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # Early prototypes added an unmarked nested tty1 block that execed
  # start-hyprland directly. Remove that whole block without touching any
  # unrelated shell startup content.
  if grep -q 'exec start-hyprland' "$file" 2>/dev/null; then
    local bare_tmp
    bare_tmp=$(mktemp)
    awk '
      !capturing && /^if \[\[.*tty1/ {
        capturing=1
        depth=1
        block=$0 ORS
        next
      }
      capturing {
        block=block $0 ORS
        if ($0 ~ /^[[:space:]]*if .*; then[[:space:]]*$/) depth++
        if ($0 ~ /^[[:space:]]*fi[[:space:]]*$/) depth--
        if (depth == 0) {
          if (block !~ /exec start-hyprland/) printf "%s", block
          capturing=0
          block=""
        }
        next
      }
      { print }
      END {
        if (capturing && block !~ /exec start-hyprland/) printf "%s", block
      }
    ' "$file" > "$bare_tmp"
    mv "$bare_tmp" "$file"
  fi
  # Drop old Omarchy-Gentoo tty1 blocks
  if grep -q 'Omarchy-Gentoo:.*[Hh]yprland\|omarchy-gentoo-session\|exec start-hyprland' "$file" 2>/dev/null; then
    local tmp
    tmp=$(mktemp)
    awk '
      /# Omarchy-Gentoo: autostart Hyprland/ {skip=1; next}
      /# Omarchy-Gentoo tty1 Hyprland/ {skip=1; next}
      /# Omarchy-Gentoo: session/ {skip=1; next}
      skip && /^$/ {skip=0; next}
      skip && /^[^#[:space:]]/ {skip=0}
      skip {next}
      {print}
    ' "$file" > "$tmp" || cp "$file" "$tmp"
    mv "$tmp" "$file"
  fi
}

PROFILE="$HOME/.bash_profile"
[[ -f "$PROFILE" ]] || PROFILE="$HOME/.profile"
touch "$PROFILE"
rewrite_autostart "$PROFILE"
if ! grep -q 'omarchy-gentoo-session' "$PROFILE" 2>/dev/null; then
  cat <<'EOF' >> "$PROFILE"

# Omarchy-Gentoo: session on tty1 (QEMU GUI / real seat)
# Uses /usr/bin/start-hyprland via omarchy-gentoo-session (do not exec Hyprland bare).
if [[ -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" && "$(tty 2>/dev/null)" == /dev/tty1 ]]; then
  command -v omarchy-gentoo-session >/dev/null 2>&1 && exec omarchy-gentoo-session
fi
EOF
fi

if [[ -f "$HOME/.bashrc" ]]; then
  rewrite_autostart "$HOME/.bashrc"
  if ! grep -q 'omarchy-gentoo-session' "$HOME/.bashrc" 2>/dev/null; then
    cat <<'EOF' >> "$HOME/.bashrc"

# Omarchy-Gentoo tty1 session (backup if .bash_profile is skipped)
if [[ $- == *i* && -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" && "$(tty 2>/dev/null)" == /dev/tty1 ]]; then
  command -v omarchy-gentoo-session >/dev/null 2>&1 && exec omarchy-gentoo-session
fi
EOF
  fi
fi

log "qemu-gui stage done — packaged Omarchy session will start on reboot"
