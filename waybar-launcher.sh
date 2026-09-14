#!/bin/bash
# waybar-launcher.sh — Lanza waybar con la zona horaria del sistema (sin hardcodear)
TZ="$(readlink -f /etc/localtime 2>/dev/null | sed 's|^.*/zoneinfo/||')"
[ -n "$TZ" ] && export TZ
exec waybar "$@"