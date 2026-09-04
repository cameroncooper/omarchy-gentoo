#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIN=4d017913d06f715da9d960021861cf535e4f15aa
VERSION=4.0.0_alpha_p20260901

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for required in \
  metadata/layout.conf \
  profiles/repo_name \
  dev-qt/qtimageformats/qtimageformats-6.11.2.ebuild \
  "gui-apps/omarchy/omarchy-${VERSION}.ebuild" \
  "gui-apps/omarchy-gentoo/omarchy-gentoo-${VERSION}-r1.ebuild" \
  "x11-themes/omarchy-themes/omarchy-themes-${VERSION}.ebuild" \
  "gui-apps/omarchy-desktop/omarchy-desktop-${VERSION}-r2.ebuild"; do
  [[ -s $ROOT/$required ]] || fail "missing $required"
done

for manifest in \
  "$ROOT/gui-apps/omarchy/Manifest" \
  "$ROOT/gui-apps/omarchy-gentoo/Manifest" \
  "$ROOT/x11-themes/omarchy-themes/Manifest" \
  "$ROOT/dev-qt/qtimageformats/Manifest"; do
  [[ -s $manifest ]] || fail "missing Manifest: $manifest"
  grep -qE 'BLAKE2B [0-9a-f]+ SHA512 [0-9a-f]+$' "$manifest" \
    || fail "Manifest digests must be lowercase: $manifest"
done

for ebuild in "$ROOT"/{dev-qt,gui-apps,x11-themes}/*/*.ebuild; do
  bash -n "$ebuild"
done

pin_count="$(grep -Rls "$PIN" "$ROOT/gui-apps/omarchy" \
  "$ROOT/gui-apps/omarchy-gentoo" "$ROOT/x11-themes/omarchy-themes" |
  grep -c '\.ebuild$')"
[[ $pin_count == 3 ]] || fail "all three source packages must use the same pin"

comm -12 \
  <(LC_ALL=C sort "$ROOT/gui-apps/omarchy-gentoo/files/adapted-commands.list") \
  <(LC_ALL=C sort "$ROOT/gui-apps/omarchy-gentoo/files/unsupported-commands.list") |
  grep -q . && fail "adapted and unsupported command sets overlap"

while IFS= read -r command; do
  [[ -f $ROOT/gui-apps/omarchy-gentoo/files/$command ]] \
    || fail "adapted command has no implementation: $command"
done < "$ROOT/gui-apps/omarchy-gentoo/files/adapted-commands.list"

if grep -Rlx 'exit 0' "$ROOT/gui-apps" "$ROOT/x11-themes" "$ROOT/scripts/qemu/guest"; then
  fail "silent success stub found"
fi

for legacy in \
  "$ROOT/scripts/qemu/guest/vendor" \
  "$ROOT/scripts/qemu/guest/adapters" \
  "$ROOT/scripts/qemu/guest/config/waybar" \
  "$ROOT/scripts/qemu/guest/bin/omarchy-gentoo-launcher"; do
  [[ ! -e $legacy ]] || fail "legacy reconstruction remains: $legacy"
done

echo "OVERLAY_STATIC_OK"
