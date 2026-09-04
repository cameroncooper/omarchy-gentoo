#!/bin/bash
# Compatibility alias — desktop overlay is the one install.
exec "$(cd "$(dirname "$0")" && pwd)/desktop.sh" "$@"
