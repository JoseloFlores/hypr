#!/bin/bash
# =============================================================================
#  Hyprland & Waybar Installer - Debian 13 (Trixie) / 14 (Forky)
#  Instalación limpia sin entorno gráfico previo
#  Resultado: Hyprland + Waybar + Thunar + greetd/tuigreet
# =============================================================================

set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LOG_FILE="$SCRIPT_DIR/install.log"
exec > >(tee -i "$LOG_FILE") 2>&1

echo "=== Hyprland Installer — Debian Trixie/Forky — $(date) ==="

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Ejecuta con sudo: sudo ./install.sh" >&2
    exit 1
fi

REAL_USER="${SUDO_USER:-${DOAS_USER:-$(logname 2>/dev/null || echo "${USER:-$(whoami)}")}}"
[ "$REAL_USER" = "root" ] && [ -n "${SUDO_USER:-}" ] && REAL_USER="$SUDO_USER"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ] && USER_HOME="$(eval echo ~"$REAL_USER")"

if [ ! -d "$USER_HOME" ]; then
    echo "ERROR: No se encontró HOME para $REAL_USER" >&2
    exit 1
fi

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# --- Detección del SO ---
# shellcheck disable=SC1091
source /etc/os-release
OS_CODENAME="${VERSION_CODENAME:-}"
if [ -z "$OS_CODENAME" ]; then
    OS_CODENAME=$(grep -oE 'trixie|forky|bookworm|sid' <<< "${VERSION:-}" | head -n1 || true)
fi
if [ -z "$OS_CODENAME" ]; then
    echo "ADVERTENCIA: No se pudo detectar VERSION_CODENAME, usando 'trixie' por defecto."
    OS_CODENAME="trixie"
fi
if [ "${ID:-}" != "debian" ]; then
    echo "ADVERTENCIA: ID detectado es '${ID:-desconocido}', esperado 'debian'. Continuando de todos modos."
fi
if [[ "$OS_CODENAME" != "trixie" && "$OS_CODENAME" != "forky" ]]; then
    echo "ADVERTENCIA: OS detectado es $OS_CODENAME. Este script está pensado para trixie o forky."
fi

# Configuración de resiliencia para APT (reintentos automáticos y timeouts)
mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99resilient <<'EOF'
Acquire::Retries "5";
Acquire::http::Timeout "20";
Acquire::https::Timeout "20";
APT::Get::Assume-Yes "true";
EOF

apt_install_resilient() {
    local max_attempts=5
    local attempt=1
    local delay=4
    until apt-get install -y --no-install-recommends "$@"; do
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "ERROR: Falló 'apt-get install' tras $max_attempts intentos para: $*" >&2
            return 1
        fi
        echo "WARN: Falló descarga/instalación (intento $attempt/$max_attempts). Reintentando en ${delay}s..." >&2
        sleep "$delay"
        dpkg --configure -a || true
        apt-get --fix-broken install -y || true
        apt-get update -o Acquire::Retries=3 || true
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
}

apt_update_resilient() {
    local max_attempts=5
    local attempt=1
    local delay=4
    until apt-get update; do
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "ERROR: Falló 'apt-get update' tras $max_attempts intentos." >&2
            return 1
        fi
        echo "WARN: Falló 'apt-get update' (intento $attempt/$max_attempts). Reintentando en ${delay}s..." >&2
        sleep "$delay"
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
}

apt_hypr_stack() {
    if [ "$OS_CODENAME" = "trixie" ]; then
        apt_install_resilient -t trixie-backports "$@"
    else
        apt_install_resilient "$@"
    fi
}

echo "-> Sistema: Debian $OS_CODENAME | Usuario: $REAL_USER"

if ! ping -c1 -W3 deb.debian.org &>/dev/null; then
    echo "ADVERTENCIA: Sin conectividad a deb.debian.org — intentando continuar..."
fi

# --- 1. Repositorios ---
echo ""
echo "1/9 Configurando repositorios (contrib non-free non-free-firmware)..."

if [ -f /etc/apt/sources.list ]; then
    sed -i -E '/^deb(-src)?\s+http/ {
        /contrib/! s/main/main contrib/
        /non-free-firmware/! s/main/main non-free-firmware/
        /non-free/! s/main/main non-free/
    }' /etc/apt/sources.list
fi

for src in /etc/apt/sources.list.d/*.sources; do
    [ -f "$src" ] || continue
    if grep -q "^Components:" "$src"; then
        sed -i -E 's/^Components:.*/Components: main contrib non-free non-free-firmware/' "$src" || true
    fi
done

if [ "$OS_CODENAME" = "trixie" ]; then
    cat > /etc/apt/sources.list.d/trixie-backports.list <<EOF
deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
EOF
    echo "-> Backports asegurado para Trixie"
fi

apt_update_resilient

# --- 2. Hardware y drivers ---
echo ""
echo "2/9 Detectando hardware e instalando drivers gráficos..."

# Base gráfica y DRM/Seat esencial para cualquier entorno (físico o VM)
apt_install_resilient libgl1-mesa-dri mesa-vulkan-drivers libegl-mesa0 libglx-mesa0 xwayland seatd libseat1 || true

if grep -qi "GenuineIntel" /proc/cpuinfo; then
    apt_install_resilient intel-microcode || true
elif grep -qi "AuthenticAMD" /proc/cpuinfo; then
    apt_install_resilient amd64-microcode || true
fi

GPU_TYPE="generic"
if lspci 2>/dev/null | grep -iq "nvidia"; then
    apt_install_resilient nvidia-driver nvidia-vaapi-driver || true
    GPU_TYPE="nvidia"
elif lspci 2>/dev/null | grep -iq "amd.*\(vga\|display\|graphics\)\|Advanced Micro Devices"; then
    apt_install_resilient mesa-va-drivers mesa-vdpau-drivers va-driver-all || true
    GPU_TYPE="amd"
elif lspci 2>/dev/null | grep -iq "intel.*\(graphics\|display\|vga\)"; then
    apt_install_resilient intel-media-va-driver-non-free va-driver-all || true
    GPU_TYPE="intel"
fi
apt_install_resilient firmware-linux-nonfree || true

# --- 3. Paquetes base ---
echo ""
echo "3/9 Instalando herramientas base + Waybar..."

apt_install_resilient \
    wget curl bc jq python3 fontconfig libnotify-bin dbus-user-session xdg-utils \
    build-essential pkg-config unzip \
    network-manager network-manager-applet nm-connection-editor iw rfkill \
    gvfs gvfs-backends gvfs-fuse gvfs-daemons udisks2 udiskie \
    thunar thunar-archive-plugin thunar-volman xarchiver tumbler ffmpegthumbnailer \
    imv mpv \
    pipewire pipewire-alsa pipewire-audio pipewire-pulse wireplumber pavucontrol \
    bluez blueman \
    sway-notification-center gnome-calendar \
    wl-clipboard cliphist brightnessctl playerctl \
    foot fuzzel swaybg grim slurp swappy wf-recorder \
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs \
    nwg-look \
    zsh vim firefox-esr zenity \
    fonts-jetbrains-mono fonts-noto-color-emoji \
    gnome-keyring libpam-gnome-keyring seahorse \
    polkitd pkexec qt6-wayland libpam-systemd \
    waybar
apt_install_resilient swayimg || echo "WARN: swayimg no disponible en $OS_CODENAME, continuando con imv" >&2 || true

apt_hypr_stack xdg-desktop-portal-hyprland || true

systemctl enable bluetooth || true

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

# --- 4. Hyprland stack ---
echo ""
echo "4/9 Instalando Hyprland..."

apt_hypr_stack hyprland hyprlock hypridle hyprpolkitagent hyprland-guiutils greetd tuigreet uwsm

# --- 5. Fuentes ---
echo ""
echo "5/9 Instalando fuentes (Meslo + Symbols)..."

FONT_DIR="$USER_HOME/.local/share/fonts"
MESLO_DIR="$FONT_DIR/Meslo"
SYMBOLS_DIR="$FONT_DIR/NerdSymbols"

sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$MESLO_DIR" "$SYMBOLS_DIR"

install_nerd_font() {
    local url="$1"
    local dest="$2"
    local tmpzip="/tmp/$(basename "$dest").zip"
    if sudo -u "$REAL_USER" env HOME="$USER_HOME" wget -q --show-progress --tries=5 --waitretry=3 --timeout=15 -O "$tmpzip" "$url"; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" unzip -o -q "$tmpzip" -d "$dest"
        rm -f "$tmpzip"
    fi
}

[ -z "$(ls -A "$MESLO_DIR" 2>/dev/null)" ] && install_nerd_font "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip" "$MESLO_DIR"
[ -z "$(ls -A "$SYMBOLS_DIR" 2>/dev/null)" ] && install_nerd_font "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip" "$SYMBOLS_DIR"

sudo -u "$REAL_USER" env HOME="$USER_HOME" fc-cache -fv "$FONT_DIR" 2>&1 | tail -n 20 || true
fc-cache -fv 2>&1 | tail -n 5 || true
chown -R "$REAL_USER":"$REAL_USER" "$FONT_DIR" || true

# --- 6. Greetd + tuigreet ---
echo ""
echo "6/9 Configurando greetd..."

mkdir -p /etc/greetd
mkdir -p /var/cache/tuigreet
chown -R _greetd: /var/cache/tuigreet || true
chmod 0755 /var/cache/tuigreet || true

cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1
[default_session]
command = "/usr/bin/tuigreet --time --remember --remember-session --asterisks --sessions /usr/share/wayland-sessions --cmd Hyprland"
user = "_greetd"
EOF

usermod -aG video,render,input _greetd || true
usermod -aG video,render,input "$REAL_USER" || true

mkdir -p /etc/systemd/system/greetd.service.d/
cat > /etc/systemd/system/greetd.service.d/override.conf <<EOF
[Service]
Restart=always
RestartSec=5
EOF
systemctl daemon-reload

# --- 7. Dots ---
echo ""
echo "7/9 Desplegando configuraciones en $USER_HOME/.config..."

DOTS_CONF="$USER_HOME/.config"
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p \
    "$DOTS_CONF/hypr" "$DOTS_CONF/waybar/themes" "$DOTS_CONF/waybar/scripts" \
    "$DOTS_CONF/swaync" "$DOTS_CONF/foot" "$DOTS_CONF/fuzzel"

for src in hyprland.conf hyprlock.conf hypridle.conf wallpaper.jpg; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
    fi
done

for src in waybar_network.sh wifi_click.sh check_updates.sh check_updates_count.sh confirm_power.sh foot_sync.sh power_menu.sh; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
        chmod +x "$DOTS_CONF/hypr/$src" 2>/dev/null || true
    fi
done

if [ -d "$SCRIPT_DIR/waybar" ]; then
    if [ -f "$SCRIPT_DIR/waybar/config.jsonc" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/waybar/config.jsonc" "$DOTS_CONF/waybar/config.jsonc"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/waybar/config.jsonc" "$DOTS_CONF/waybar/config"
    fi
    if [ -f "$SCRIPT_DIR/waybar/style.css" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/waybar/style.css" "$DOTS_CONF/waybar/style.css"
    fi
    for th in "$SCRIPT_DIR/waybar/themes"/*.css; do
        [ -f "$th" ] || continue
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$th" "$DOTS_CONF/waybar/themes/"
    done
    for sh in "$SCRIPT_DIR/waybar/scripts"/*.sh; do
        [ -f "$sh" ] || continue
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$sh" "$DOTS_CONF/waybar/scripts/"
        chmod +x "$DOTS_CONF/waybar/scripts/$(basename "$sh")"
    done
else
    echo "WARN: No se encontró $SCRIPT_DIR/waybar, se omite despliegue Waybar"
fi

for app in foot fuzzel; do
    if [ -f "$SCRIPT_DIR/$app.ini" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$app.ini" "$DOTS_CONF/$app/$app.ini"
        echo "-> $app.ini desplegado en $DOTS_CONF/$app/"
    fi
done

if [ -f "$SCRIPT_DIR/swaync_config.json" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/swaync_config.json" "$DOTS_CONF/swaync/config.json"
fi
if [ -f "$SCRIPT_DIR/swaync_style.css" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/swaync_style.css" "$DOTS_CONF/swaync/style.css"
fi

HYPR_CONF="$DOTS_CONF/hypr/hyprland.conf"
if [ "$GPU_TYPE" = "nvidia" ] && [ -f "$HYPR_CONF" ]; then
    sed -i '/^# NVIDIA_ENV_BEGIN/,/^# NVIDIA_ENV_END/{s/^# env =/env =/;}' "$HYPR_CONF"
    echo "-> hyprland.conf: variables NVIDIA activadas"
fi

find "$DOTS_CONF/hypr" "$DOTS_CONF/waybar" "$DOTS_CONF/swaync" -type f \( -name "*.sh" -o -name "*.jsonc" -o -name "config" -o -name "*.conf" -o -name "*.css" -o -name "*.ini" \) \
    -exec sed -i -E "s|/home/[^/]+|$USER_HOME|g" {} + 2>/dev/null || true

chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

# --- 8. PAM y portales ---
echo ""
echo "8/9 Finalizando permisos y PAM..."

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

# --- 9. Servicios y configuración de red ---
echo ""
echo "9/9 Configurando servicios y preparación de red..."

# Configurar NetworkManager para que administre interfaces tras reiniciar, sin interrumpir la red actual
echo "-> Preparando configuración de NetworkManager para el próximo arranque..."
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
    echo "-> /etc/network/interfaces reseteado a solo lo (backup creado, tomará efecto tras reboot)"
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

echo ""
echo "--- DIAGNÓSTICO FINAL ---"
echo "Sistema: Debian $OS_CODENAME"

if pkg_installed waybar; then
    echo "Waybar: $(dpkg-query -W -f='${Version}' waybar) ($(command -v waybar || echo /usr/bin/waybar))"
else
    echo "Waybar: no instalado"
fi

if pkg_installed hyprland; then
    echo "Hyprland: $(dpkg-query -W -f='${Version}' hyprland) ($(command -v Hyprland || command -v start-hyprland || echo /usr/bin/Hyprland))"
else
    echo "Hyprland: no instalado — REVISAR apt logs arriba"
fi

echo "Greetd: $(systemctl is-enabled greetd 2>&1 || echo 'no habilitado')"
if pkg_installed tuigreet; then
    echo "Tuigreet: $(dpkg-query -W -f='${Version}' tuigreet)"
else
    echo "Tuigreet: no instalado"
fi
if pkg_installed xdg-desktop-portal-hyprland; then
    echo "Portal Hyprland: $(dpkg-query -W -f='${Version}' xdg-desktop-portal-hyprland)"
else
    echo "Portal Hyprland: no instalado (advertencia)"
fi

echo "-------------------------------------------------------"
if pkg_installed hyprland && pkg_installed waybar; then
    echo "¡INSTALACIÓN COMPLETADA!"
else
    echo "¡INSTALACIÓN INCOMPLETA! Revisa errores de apt arriba."
    exit 1
fi
if [ "$GPU_TYPE" = "nvidia" ]; then
    echo "AVISO NVIDIA: añade 'nvidia-drm.modeset=1' a GRUB_CMDLINE_LINUX en /etc/default/grub y ejecuta: update-grub"
fi
echo "Reinicia: sudo reboot"
