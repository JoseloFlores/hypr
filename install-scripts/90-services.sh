#!/bin/bash
# 90-services.sh — Servicios y red NetworkManager (paso 9/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "90-services"

log "9/10 Configurando servicios y preparación de red..."

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] NM managed=true + reset interfaces + enable NM/bluetooth/greetd + mask getty@tty1" | tee -a "$LOG"
    exit 0
fi

log "-> Preparando configuración de NetworkManager para el próximo arranque..."
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf <<'NMCONF'
[keyfile]
unmanaged-devices=none
NMCONF
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    sed -i -E "s/managed=false/managed=true/" /etc/NetworkManager/NetworkManager.conf || true
    grep -q "^\[ifupdown\]" /etc/NetworkManager/NetworkManager.conf || echo -e "\n[ifupdown]\nmanaged=true" >> /etc/NetworkManager/NetworkManager.conf
fi
if [ -f /etc/network/interfaces ] && grep -qE "wlp|wlan|eth|enp|ens" /etc/network/interfaces 2>/dev/null; then
    cp /etc/network/interfaces "/etc/network/interfaces.bak.$(date +%s)"
    cat > /etc/network/interfaces <<'IFACE'
auto lo
iface lo inet loopback
IFACE
    log "-> /etc/network/interfaces reseteado a solo lo (backup creado, tomará efecto tras reboot)"
fi
if [ -f /etc/dhcpcd.conf ] && ! grep -q "denyinterfaces" /etc/dhcpcd.conf 2>/dev/null; then
    echo "denyinterfaces wlan* wlp* eth* enp* ens*" >> /etc/dhcpcd.conf || true
fi
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable bluetooth 2>/dev/null || true
rfkill unblock all 2>/dev/null || true

systemctl disable sddm lightdm gdm gdm3 2>/dev/null || true
systemctl mask getty@tty1.service 2>/dev/null || true
systemctl enable greetd
log_ok "Servicios OK"
