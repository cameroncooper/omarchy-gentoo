#!/bin/bash
# Download pinned Gentoo stage3 + minimal ISO.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/config.sh"
ensure_dirs

file_size() {
  local f="$1"
  if /usr/bin/stat -f%z "$f" >/dev/null 2>&1; then
    /usr/bin/stat -f%z "$f"
  else
    /usr/bin/stat -c%s "$f"
  fi
}

# Expected sizes from Gentoo latest manifests (fail closed if wrong)
STAGE3_EXPECTED_BYTES="${STAGE3_EXPECTED_BYTES:-260946120}"
ISO_EXPECTED_BYTES="${ISO_EXPECTED_BYTES:-836775936}"

fetch() {
  local url="$1" dest="$2" expected="$3"
  if [[ -f "$dest" ]]; then
    local sz
    sz=$(file_size "$dest")
    if [[ "$sz" == "$expected" ]]; then
      echo "ok: $(basename "$dest") (${sz} bytes)"
      return 0
    fi
    echo "size mismatch for $(basename "$dest"): got ${sz}, expected ${expected} — re-fetching"
    rm -f "$dest"
  fi
  echo "fetch: $url"
  curl -L --fail --retry 3 -o "${dest}.partial" "$url"
  local psz
  psz=$(file_size "${dest}.partial")
  if [[ "$psz" != "$expected" ]]; then
    echo "FATAL: downloaded size ${psz} != expected ${expected}" >&2
    rm -f "${dest}.partial"
    exit 1
  fi
  mv "${dest}.partial" "$dest"
  echo "saved: $dest ($psz bytes)"
}

mkdir -p "$ARTIFACTS"
fetch "$STAGE3_URL" "$STAGE3_LOCAL" "$STAGE3_EXPECTED_BYTES"
fetch "$ISO_URL" "$ISO_LOCAL" "$ISO_EXPECTED_BYTES"

cat > "$ARTIFACTS/PINNED.txt" << EOF
GENTOO_BUILD=$GENTOO_BUILD
STAGE3_URL=$STAGE3_URL
ISO_URL=$ISO_URL
STAGE3_EXPECTED_BYTES=$STAGE3_EXPECTED_BYTES
ISO_EXPECTED_BYTES=$ISO_EXPECTED_BYTES
BINHOST_URI=$BINHOST_URI
DISK_SIZE_GB=$DISK_SIZE_GB
fetched_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "artifacts ready under $ARTIFACTS"
