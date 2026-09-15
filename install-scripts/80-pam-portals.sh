#!/bin/bash
# 80-pam-portals.sh — PAM gnome-keyring + portales xdg (paso 8/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "80-pam-portals"

log "8/10 Finalizando permisos y PAM..."

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] pam-auth-update gnome-keyring + /etc/pam.d/greetd + hyprland-portals.conf" | tee -a "$LOG"
    exit 0
fi

if command -v pam-auth-update &>/dev/null; then
    pam-auth-update --enable gnome-keyring || true
fi

if [ ! -f /etc/pam.d/greetd ]; then
    cat > /etc/pam.d/greetd <<'PAMGREETD'
#%PAM-1.0
auth    requisite       pam_nologin.so
auth    required        pam_env.so
auth    optional        pam_gnome_keyring.so
@include common-auth
@include common-account
@include common-session
session optional        pam_gnome_keyring.so auto_start
@include common-password
PAMGREETD
fi

mkdir -p /etc/xdg/xdg-desktop-portal
if [ ! -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf ]; then
    cat > /etc/xdg/xdg-desktop-portal/hyprland-portals.conf <<'PORTAL'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
PORTAL
fi
log_ok "PAM + portales OK"
