#!/bin/bash
# uninstall-lite.sh — Desinstalación LITE y segura (solo revierte dots, no purga sistema)
# Uso: sudo ./uninstall-lite.sh [--full]
#  sin flags: quita dots desplegados + timer de usuario (con confirmación)
#  --full: además disable greetd y borra /etc/greetd override + portales creados por el repo
set -eo pipefail
REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
FULL=0; [[ "${1:-}" == "--full" ]] && FULL=1

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER:-$(whoami)}")}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
echo "Usuario: $REAL_USER ($USER_HOME) | modo: $([[ $FULL -eq 1 ]] && echo FULL || echo LITE)"
read -r -p "¿Continuar? [s/N] " ans
[[ "$ans" =~ ^[sSyY]$ ]] || { echo "Cancelado."; exit 0; }

DOTS_CONF="$USER_HOME/.config"
echo "-> Deteniendo timer auto-timezone..."
sudo -u "$REAL_USER" env HOME="$USER_HOME" systemctl --user stop auto-timezone.timer 2>/dev/null || true
sudo -u "$REAL_USER" env HOME="$USER_HOME" systemctl --user disable auto-timezone.timer 2>/dev/null || true
rm -f "$DOTS_CONF/systemd/user/auto-timezone.service" "$DOTS_CONF/systemd/user/auto-timezone.timer"

echo "-> Borrando dots desplegados por este repo (se conserva backup con fecha)..."
BAK="$USER_HOME/.config.hypr-bak-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BAK"
for d in hypr noctalia foot; do
    [ -e "$DOTS_CONF/$d" ] && mv "$DOTS_CONF/$d" "$BAK/$(echo "$d" | tr '/' '_')" 2>/dev/null || true
done
echo "Backup en: $BAK"

if [ $FULL -eq 1 ]; then
    echo "-> FULL: deshabilitando greetd y limpiando overrides del repo..."
    systemctl disable greetd 2>/dev/null || true
    rm -f /etc/systemd/system/greetd.service.d/override.conf
    rm -f /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
    rm -f /etc/udev/rules.d/90-backlight.rules
    rm -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf
    systemctl daemon-reload || true
    echo "NOTA: no se purgan paquetes (usa 'apt autoremove hyprland noctalia' manual si lo quieres)."
fi
echo "Listo."
