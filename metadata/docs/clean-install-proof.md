# Clean-install proof

Validated on 2026-09-03 from the untouched Phase A Gentoo aarch64 image,
using public repository commit `d9159eba9d841194c7c405fc93e36d5844a5b269`.
The guest initially had no Omarchy package and no `/usr/share/omarchy`.

The validation followed the README's unregistered-overlay flow:

1. Select `default/linux/arm64/23.0/desktop/systemd` and update `@world`.
2. Enable and sync GURU and hyproverlay.
3. Add `https://github.com/cameroncooper/omarchy-gentoo.git` with
   `eselect repository add`.
4. Apply the documented arm64 hyproverlay keyword acceptance.
5. Apply Portage's generated autounmask changes and emerge
   `gui-apps/omarchy-desktop`.
6. Enable the documented NetworkManager and Bluetooth services.
7. Boot `omarchy-gentoo-session` through tty1 autologin in QEMU.

Installed package versions:

```text
gui-apps/omarchy-4.0.0_alpha_p20260901
gui-apps/omarchy-gentoo-4.0.0_alpha_p20260901-r2
gui-apps/omarchy-desktop-4.0.0_alpha_p20260901-r3
gui-apps/quickshell-0.3.0-r1
gui-wm/hyprland-0.56.2
dev-libs/wayland-1.26.0
```

Runtime checks passed:

- Hyprland and Quickshell started after reboot.
- Hyprland used the normal packaged Adwaita pointer instead of its logo fallback.
- Quickshell ran from `/usr/share/omarchy/shell`.
- The packaged tree contained 441 upstream commands and 22 themes.
- `omarchy-shell shell ping` and `omarchy-menu summon` returned `ok`.
- The menu definition contained four populated top-level sections.
- `omarchy-theme-set catppuccin` returned success and survived reboot.
- `hyprctl configerrors` was empty.
- Repeated `omarchy-user-init --if-needed` produced no output or state change.
- PipeWire, PipeWire Pulse, and WirePlumber started with the packaged session.
- Arch administration commands returned the intentional unsupported status 69.

The QEMU guest had no Bluetooth controller, so systemd correctly skipped
`bluetooth.service` via its hardware condition. Missing RTKit produced
non-fatal realtime-priority warnings; there were no failed user units.
