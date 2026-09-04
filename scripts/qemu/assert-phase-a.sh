#!/bin/bash
# Assert Phase A contract over SSH.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/config.sh"

ssh() { "$HARNESS/vm.sh" ssh "$@"; }

echo "assert: marker"
ssh "test -f $PHASE_A_MARKER"

echo "assert: identity"
ssh "test \"\$(hostname)\" = \"$HOSTNAME\""
ssh "id -un | grep -qx $GUEST_USER"
ssh "sudo -n true"

echo "assert: init + ssh"
ssh "test \"\$(ps -p 1 -o comm=)\" = systemd"
ssh "systemctl is-active sshd"

echo "assert: arch + disk budget"
ssh "uname -m | grep -qx aarch64"
# Leave headroom for Phase B experiments on 20G
ssh "python3 - <<'PY'
import os
st=os.statvfs('/')
free_gb=(st.f_bavail*st.f_frsize)/1024/1024/1024
print(f'free_gb={free_gb:.2f}')
raise SystemExit(0 if free_gb >= 6.0 else 1)
PY
" || ssh "df -h /; python3 -c \"import os;st=os.statvfs('/');print((st.f_bavail*st.f_frsize)/1024/1024/1024)\""

echo "assert: portage + binhost configured"
ssh "test -f /etc/portage/binrepos.conf/gentoobinhost.conf"
ssh "grep -q getbinpkg /etc/portage/make.conf"

echo "assert: tools"
ssh "command -v emerge && command -v grub-install && command -v sudo"

echo "PHASE_A_ASSERT_OK"
