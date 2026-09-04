# VM desktop validation

`scripts/qemu/guest/` is the guest-side validation driver. The real desktop is
represented by ebuilds at the repository root.

```bash
./scripts/qemu/desktop.sh --from-golden
```

The driver registers this checkout as `omarchy-gentoo`, emerges
`gui-apps/omarchy-desktop`, runs `omarchy-user-init`, and asserts the packaged
tree and command boundary. It does not copy a vendored subset into the user's
home.

Hyprland and Quickshell still compile on the arm64 QEMU guest, so the harness
uses a 64 GiB virtual disk.
