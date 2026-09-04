#!/bin/bash
# Assert the packaged upstream runtime and the narrow Gentoo integration.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

OMARCHY_HOME=/usr/share/omarchy

log "assert package installation"
qlist -IC gui-apps/omarchy >/dev/null || die "gui-apps/omarchy is not installed"
qlist -IC gui-apps/omarchy-gentoo >/dev/null || die "gui-apps/omarchy-gentoo is not installed"
qlist -IC gui-apps/omarchy-desktop >/dev/null || die "desktop metapackage is not installed"

log "assert comprehensive pinned upstream tree"
[[ $(<"$OMARCHY_HOME/version") == "4.0.0.alpha" ]] || die "unexpected upstream version"
[[ -f $OMARCHY_HOME/LICENSE ]] || die "upstream license missing"
[[ -f $OMARCHY_HOME/default/hypr/bootstrap.lua ]] || die "Hyprland defaults missing"
[[ -f $OMARCHY_HOME/default/omarchy/omarchy-menu.jsonc ]] || die "menu definition missing"
[[ -f $OMARCHY_HOME/shell/shell.qml ]] || die "Quickshell source missing"
[[ -f $OMARCHY_HOME/config/hypr/hyprland.lua ]] || die "upstream user config missing"
[[ -d $OMARCHY_HOME/install && -d $OMARCHY_HOME/migrations ]] \
  || die "full upstream administration tree was not packaged"
(( $(find "$OMARCHY_HOME/bin" -maxdepth 1 -type f | wc -l) >= 400 )) \
  || die "upstream bin tree is incomplete"
(( $(find "$OMARCHY_HOME/themes" -mindepth 1 -maxdepth 1 -type d | wc -l) >= 20 )) \
  || die "upstream themes are incomplete"

log "assert Gentoo command boundary"
have_cmd omarchy-shell || die "portable upstream commands not exposed"
have_cmd omarchy-menu || die "Omarchy menu command missing"
have_cmd omarchy-pkg-list || die "Portage package backend missing"
have_cmd omarchy-gentoo-session || die "Gentoo session missing"
have_cmd quickshell || die "Quickshell dependency missing"
have_cmd Hyprland || die "Hyprland dependency missing"
omarchy-version | grep -q 'Gentoo integration' || die "Gentoo version adapter inactive"
set +e
omarchy-update >/tmp/omarchy-unsupported.out 2>&1
unsupported_status=$?
set -e
[[ $unsupported_status == 69 ]] || die "Arch update command was not blocked clearly"
grep -q 'Use Portage directly' /tmp/omarchy-unsupported.out \
  || die "unsupported command did not explain the Portage boundary"

log "assert idempotent user activation"
omarchy-user-init --if-needed
[[ -f $HOME/.config/hypr/hyprland.lua ]] || die "Hyprland user config missing"
[[ -f $HOME/.config/omarchy/shell.json ]] || die "shell user config missing"
[[ -s $HOME/.local/state/omarchy/current/theme.name ]] || die "initial theme missing"
[[ -e $HOME/.local/state/omarchy/current/background ]] || die "initial background missing"
grep -q '/usr/share/omarchy' /usr/bin/omarchy-gentoo-session \
  || die "session does not use the packaged upstream tree"

if pgrep -x quickshell >/dev/null 2>&1; then
  ps -o args= -p "$(pgrep -n quickshell)" | grep -q '/usr/share/omarchy/shell' \
    || die "running Quickshell still uses a prototype home-local tree"
  ! pgrep -x waybar >/dev/null 2>&1 \
    || die "legacy Waybar is running alongside Omarchy shell"
fi

log "DESKTOP_ASSERT_OK"
