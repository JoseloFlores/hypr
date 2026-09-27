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

# greetd trae su propio /etc/pam.d/greetd por paquete: el `if ! -f` original
# nunca lo parcheaba y el llavero quedaba bloqueado -> Chrome pedía contraseña.
# Orden correcto (portable, idempotente): auth pam_gnome_keyring DESPUÉS de
# common-auth (necesita el authtok de pam_unix) y session auto_start al final.
# Se normaliza siempre: vale para el archivo empaquetado y para el creado aquí.
if [ ! -f /etc/pam.d/greetd ]; then
    cat > /etc/pam.d/greetd <<'PAMGREETD'
#%PAM-1.0
@include common-auth
auth    optional        pam_gnome_keyring.so
@include common-account
@include common-session
session optional        pam_gnome_keyring.so auto_start
@include common-password
PAMGREETD
fi
# Limpia líneas previas (evita duplicados y corrige el auth-antes-de-common-auth
# que trae Debian y que dejaba el llavero `login` bloqueado).
sed -i '/pam_gnome_keyring\.so/d' /etc/pam.d/greetd
sed -i '/@include common-auth/a auth    optional        pam_gnome_keyring.so' /etc/pam.d/greetd
echo 'session optional        pam_gnome_keyring.so auto_start' >> /etc/pam.d/greetd

mkdir -p /etc/xdg/xdg-desktop-portal
if [ ! -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf ]; then
    cat > /etc/xdg/xdg-desktop-portal/hyprland-portals.conf <<'PORTAL'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
PORTAL
fi
log_ok "PAM + portales OK"
