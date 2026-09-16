#!/bin/bash
# 30-base.sh — Paquetes base + Waybar + backlight + locales (paso 3/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "30-base"

log "3/10 Instalando herramientas base + Waybar..."

BASE_PKGS=(
    wget curl bc jq python3 fontconfig libnotify-bin dbus-user-session xdg-utils
    build-essential pkg-config unzip
    network-manager network-manager-applet nm-connection-editor iw rfkill
    gvfs gvfs-backends gvfs-fuse gvfs-daemons udisks2 udiskie
    pipewire pipewire-alsa pipewire-audio pipewire-pulse wireplumber pavucontrol
    alsa-utils alsa-ucm-conf libspa-0.2-bluetooth
    bluez blueman
    sway-notification-center thunderbird
    wl-clipboard cliphist brightnessctl playerctl
    foot fuzzel swaybg grim slurp swappy wf-recorder
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs
    nwg-look
    zsh vim firefox-esr zenity
    fonts-jetbrains-mono fonts-noto-color-emoji fonts-firacode
    gnome-keyring libpam-gnome-keyring seahorse
    polkitd pkexec qt6-wayland libpam-systemd
    waybar
)
# Thunar / multimedia opcionales por preset
if [ "${INSTALL_THUNAR:-ON}" != "OFF" ]; then
    BASE_PKGS+=(thunar thunar-archive-plugin thunar-volman xarchiver tumbler ffmpegthumbnailer)
fi
if [ "${INSTALL_MEDIA:-ON}" != "OFF" ]; then
    BASE_PKGS+=(imv swayimg mpv)
fi
if [ "${INSTALL_ZSH_EXTRA:-OFF}" = "ON" ]; then
    BASE_PKGS+=(zsh)
fi

apt_install_resilient "${BASE_PKGS[@]}"
apt_hypr_stack xdg-desktop-portal-hyprland || true

run_cmd systemctl enable bluetooth || true

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] udev 90-backlight.rules + locale-gen + xdg-user-dirs-update" | tee -a "$LOG"
    exit 0
fi

cat > /etc/udev/rules.d/90-backlight.rules <<'UDEV'
SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
UDEV
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger --subsystem-match=backlight --action=add 2>/dev/null || true
for bl in /sys/class/backlight/*/brightness; do
    [ -e "$bl" ] || continue
    chgrp video "$bl" 2>/dev/null || true
    chmod g+w "$bl" 2>/dev/null || true
done

if command -v locale-gen >/dev/null 2>&1; then
    for loc in es_ES.UTF-8 es_AR.UTF-8; do
        if ! locale -a 2>/dev/null | grep -qi "^${loc}$\|^${loc%%.*}"; then
            sed -i -E "s/^# *${loc}/${loc}/" /etc/locale.gen 2>/dev/null || true
            grep -q "^${loc}" /etc/locale.gen 2>/dev/null || echo "${loc} UTF-8" >> /etc/locale.gen
        fi
    done
    locale-gen es_ES.UTF-8 es_AR.UTF-8 >/dev/null 2>&1 || locale-gen || true
fi

USER_LANG="$(sudo -u "$REAL_USER" bash -lc 'printf %s "${LANG:-}"' 2>/dev/null || true)"
if locale -a 2>/dev/null | grep -qi 'es_ES'; then
    XDG_LANG="es_ES.UTF-8"
elif [ -n "$USER_LANG" ]; then
    XDG_LANG="$USER_LANG"
else
    XDG_LANG="C.UTF-8"
fi
sudo -u "$REAL_USER" env HOME="$USER_HOME" LANG="$XDG_LANG" xdg-user-dirs-update --force || true
sudo -u "$REAL_USER" env HOME="$USER_HOME" bash -c 'thunar -q 2>/dev/null || true' || true
log_ok "Base OK"
