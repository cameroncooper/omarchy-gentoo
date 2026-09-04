#!/bin/bash
# Compatibility alias — desktop overlay includes the Omarchy shell.
exec "$(cd "$(dirname "$0")" && pwd)/desktop.sh" "$@"
