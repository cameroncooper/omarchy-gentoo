# Philosophy

Omarchy-on-Gentoo is an upstream-preserving desktop port, not a distro clone
and not a visual reconstruction.

- Gentoo owns boot, packages, services, hardware policy, and updates.
- Upstream Omarchy owns its runtime tree: Hyprland Lua, Quickshell, menus,
  themes, defaults, and portable commands.
- Compatibility code is isolated in `gui-apps/omarchy-gentoo`.
- No fake command may return success. Unsupported Arch administration fails
  explicitly until it has a tested Portage implementation.
- Portage never writes users' homes. User activation creates missing files and
  preserves customizations.
- Optional applications are dependency policy, not edits to the upstream menu
  or shell.

The QEMU harness validates the repository; it is not the product installer.
