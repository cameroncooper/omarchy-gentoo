#!/bin/bash
# Register this checkout as a local Gentoo repository for VM validation.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"

log "register local omarchy-gentoo repository → $REPO_ROOT"
sudo mkdir -p /etc/portage/repos.conf /etc/portage/package.accept_keywords
cat <<EOF | sudo tee /etc/portage/repos.conf/omarchy-gentoo.conf >/dev/null
[omarchy-gentoo]
location = $REPO_ROOT
masters = gentoo
auto-sync = no
EOF

echo '*/*::omarchy-gentoo ~arm64' |
  sudo tee /etc/portage/package.accept_keywords/omarchy-gentoo >/dev/null

log "local repository registered"
