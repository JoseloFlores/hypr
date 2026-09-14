#!/bin/bash
# waybar-launcher.sh — Sincroniza waybar con la zona horaria del sistema.
# Exporta TZ desde /etc/localtime (sin hardcodear): lo necesitan los módulos clock
# de waybar 0.12, cuyo std::chrono::current_zone() falla a UTC sin esta variable.
TZ="$(readlink -f /etc/localtime 2>/dev/null | sed 's|^.*/zoneinfo/||')"
[ -n "$TZ" ] && export TZ
exec waybar "$@"
