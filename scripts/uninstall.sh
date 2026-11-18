#!/usr/bin/env bash
# Switch and restart before removal: work around the host bar-loader transition.
# Omarchy's normal removal confirmation is retained unless --yes is passed.
set -euo pipefail
omarchy bar use omarchy.bar
omarchy restart shell
exec omarchy plugin remove anky.dwm-bar "$@"
