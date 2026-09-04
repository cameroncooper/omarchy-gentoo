# Omarchy on Gentoo

An actual Gentoo repository for the upstream Omarchy desktop. Gentoo owns the
operating system and packages; the pinned upstream Omarchy source owns the
Hyprland configuration, Quickshell UI, menus, themes, and portable CLI.

This repository does not rebuild an Omarchy-like desktop. It installs upstream
Omarchy 4.0.0.alpha commit `4d017913d06f715da9d960021861cf535e4f15aa`
under `/usr/share/omarchy` and keeps Gentoo compatibility in a separate package.

## Packages

| Package | Purpose |
| --- | --- |
| `gui-apps/omarchy` | Immutable upstream runtime tree |
| `x11-themes/omarchy-themes` | All 22 upstream themes and wallpapers |
| `gui-apps/omarchy-gentoo` | Portage package queries, user activation, session and command boundary |
| `gui-apps/omarchy-desktop` | Minimal Hyprland/Quickshell desktop dependencies |
| `gui-apps/omarchy-desktop-full` | Optional development/media/office groups |

Zoom, Spotify, 1Password, and other proprietary applications are never
dependencies of the minimal desktop. Install those explicitly if wanted.

## Install as an unregistered overlay

Omarchy-Gentoo currently depends on Hyprland from hyproverlay and Quickshell
from GURU:

```bash
emerge --ask app-eselect/eselect-repository
eselect repository enable hyproverlay guru
emaint sync -r hyproverlay
emaint sync -r guru
```

Add this Git repository using Portage's native repository manager:

```bash
eselect repository add omarchy-gentoo git https://github.com/cameroncooper/omarchy-gentoo.git
emaint sync -r omarchy-gentoo
```

Then:

```bash
emerge --ask --verbose --autounmask-write gui-apps/omarchy-desktop
dispatch-conf
emerge --ask --verbose gui-apps/omarchy-desktop
```

Select `Omarchy` in a Wayland session chooser or run
`omarchy-gentoo-session` from a graphical VT.

The first session automatically initializes only missing files under
`~/.config` and `~/.local/state`; it never uses `rsync --delete` and never
overwrites user configuration.

Updates use the normal Gentoo flow:

```bash
emaint sync -r omarchy-gentoo
emerge --ask --update --deep --newuse @world
```

## Compatibility boundary

All upstream commands are shipped. Portable commands resolve directly to the
upstream files in `/usr/share/omarchy/bin`. Commands that administer Arch
packages, migrations, installs, removals, or updates return a clear
“use Portage” error in the first compatibility milestone.

Package-presence checks used by the menu are backed by Portage. This keeps the
desktop intact without pretending that pacman exists.

## Optional applications

Use `gui-apps/omarchy-desktop-full` for broad open-source groups:

```bash
USE="development -media -office" \
  emerge --ask gui-apps/omarchy-desktop-full
```

For per-application control, copy
`metadata/examples/omarchy-upstream-apps.set` to
`/etc/portage/sets/omarchy-upstream-apps`, edit it, and emerge the set.

## QEMU validation

The Apple Silicon QEMU harness remains test infrastructure for `~arm64`:

```bash
./scripts/qemu/phase-a.sh
./scripts/qemu/desktop.sh --from-golden
./scripts/qemu/start-gui.sh
```

The harness installs `gui-apps/omarchy-desktop`, exactly as a user does. It no
longer seeds a hand-picked Omarchy subset into a home directory.
