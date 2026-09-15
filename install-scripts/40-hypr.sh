#!/bin/bash
# 40-hypr.sh — Hyprland stack (paso 4/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "40-hypr"

log "4/10 Instalando Hyprland..."
apt_hypr_stack hyprland hyprlock hypridle hyprpolkitagent hyprland-guiutils greetd tuigreet uwsm
log_ok "Hyprland stack OK"
