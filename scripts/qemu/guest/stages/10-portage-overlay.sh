#!/bin/bash
# Enable hyproverlay + accept keywords; Portage USE for Wayland desktop.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

log "install eselect-repository if needed"
if ! have_cmd eselect || ! eselect repository list &>/dev/null; then
  emerge_quiet app-eselect/eselect-repository
fi

log "enable hyproverlay"
if [[ ! -d /var/db/repos/hyproverlay ]]; then
  sudo eselect repository enable hyproverlay
fi
sudo emaint sync -r hyproverlay || sudo emerge --sync hyproverlay || true
# Ensure tree exists
[[ -d /var/db/repos/hyproverlay ]] || die "hyproverlay sync failed"

# GURU: Quickshell (omarchy-shell)
if [[ ! -d /var/db/repos/guru ]]; then
  sudo eselect repository enable guru || warn "could not enable ::guru"
fi
if [[ -d /var/db/repos/guru ]]; then
  sudo emaint sync -r guru || true
  echo '*/*::guru ~arm64' | sudo tee /etc/portage/package.accept_keywords/guru >/dev/null
fi

log "accept hyproverlay keywords + common ::gentoo testing deps"
sudo mkdir -p /etc/portage/package.accept_keywords /etc/portage/package.mask
echo '*/*::hyproverlay **' | sudo tee /etc/portage/package.accept_keywords/hyproverlay >/dev/null
# Never use live ebuilds for the overlay install — pin releases only
cat <<'EOF' | sudo tee /etc/portage/package.mask/hyproverlay-live >/dev/null
*/*-9999::hyproverlay
EOF
# Fallback explicit masks if glob unsupported
for p in gui-libs/aquamarine gui-libs/hyprutils gui-libs/hyprcursor gui-libs/hyprgraphics \
         gui-libs/hyprwire gui-libs/hyprtoolkit gui-libs/hyprland-guiutils \
         gui-libs/xdg-desktop-portal-hyprland gui-wm/hyprland \
         gui-apps/hyprpaper gui-apps/hypridle gui-apps/hyprlock \
         dev-libs/hyprland-protocols dev-libs/hyprlang dev-util/hyprwayland-scanner; do
  echo "=${p}-9999::hyproverlay" | sudo tee -a /etc/portage/package.mask/hyproverlay-live >/dev/null
done
# Hyprland pulls several ~arm64 packages from ::gentoo
cat <<'EOF' | sudo tee /etc/portage/package.accept_keywords/hyprland-gentoo-deps >/dev/null
dev-cpp/tomlplusplus ~arm64
dev-libs/hyprland-protocols ~arm64
dev-util/hyprwayland-scanner ~arm64
gui-libs/aquamarine ~arm64
gui-libs/hyprcursor ~arm64
gui-libs/hyprgraphics ~arm64
gui-libs/hyprlang ~arm64
gui-libs/hyprutils ~arm64
gui-libs/hyprwire ~arm64
dev-libs/hyprlang ~arm64
dev-libs/udis86 ~arm64
dev-libs/wayland ~arm64
dev-libs/wayland-protocols ~arm64
dev-util/wayland-scanner ~arm64
EOF

# Hyprland / Wayland USE nudges (keep lean)
sudo mkdir -p /etc/portage/package.use
cat <<'EOF' | sudo tee /etc/portage/package.use/omarchy-gentoo >/dev/null
media-video/pipewire pipewire-alsa sound-server ssl
sys-apps/xdg-desktop-portal gstreamer
media-libs/libcanberra udev alsa
# Hyprland GUI utils (dialogs/popups) — release ebuilds only
gui-wm/hyprland guiutils -hyprpm -X
EOF
# Waybar needs a working Settings portal. gtk+[wayland]-only breaks
# xdg-desktop-portal-gtk (missing gdk_x11_*); keep X+wayland together.
cat <<'EOF' | sudo tee /etc/portage/package.use/omarchy-gtk-portal >/dev/null
x11-libs/gtk+ X wayland
sys-apps/xdg-desktop-portal-gtk wayland X
EOF
# Avoid live cairo pulls when enabling gtk X
echo 'x11-libs/cairo:9999' | sudo tee /etc/portage/package.mask/omarchy-cairo-live >/dev/null

# Omarchy bar is Quickshell. Pin Qt source USE so 6.11 binpkgs don't
# conflict with the flags the ebuild needs (seen on arm64 2026-09).
cat <<'EOF' | sudo tee /etc/portage/package.use/omarchy-quickshell >/dev/null
gui-apps/quickshell hyprland wayland layer-shell notifications tray pipewire policykit
dev-qt/qtbase:6 vulkan wayland opengl
dev-qt/qtdeclarative:6 opengl vulkan
dev-qt/qtwayland:6
EOF

# Ensure getbinpkg remains on for everything that can use it
if ! grep -q getbinpkg /etc/portage/make.conf; then
  echo 'FEATURES="${FEATURES} getbinpkg"' | sudo tee -a /etc/portage/make.conf >/dev/null
fi

log "portage overlay ready"
