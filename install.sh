#!/bin/bash
# =============================================================================
#  Hyprland & Waybar Installer - Debian 13 (Trixie) / 14 (Forky)
#  Instalación Limpia sin entorno gráfico
#  Resultado: Hyprland + Waybar + Nautilus + GNOME comforts
# =============================================================================

set -eo pipefail

# --- Logging ---
SCRIPT_DIR_TMP=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LOG_FILE="$SCRIPT_DIR_TMP/install.log"
exec > >(tee -i "$LOG_FILE") 2>&1

echo "=== Hyprland Installer — Debian Trixie/Forky — $(date) ==="

# --- 0. Validaciones y Detección del SO ---
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

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CPU_CORES=$(nproc)

# Detectar versión de Debian — robusto para trixie/forky, soporta DEB822 y fallback
source /etc/os-release
OS_CODENAME="${VERSION_CODENAME:-}"
if [ -z "$OS_CODENAME" ]; then
    # Fallback: extraer de VERSION ("13 (trixie)") si VERSION_CODENAME vacío (containers mínimos)
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
    echo "ADVERTENCIA: OS detectado es $OS_CODENAME. Este script está optimizado para trixie o forky."
fi

echo "-> Sistema: Debian $OS_CODENAME | Usuario: $REAL_USER | Cores: $CPU_CORES"

if ! ping -c1 -W3 deb.debian.org &>/dev/null; then
    echo "ADVERTENCIA: Sin conectividad a deb.debian.org — intentando continuar..."
fi

# --- 1. Repositorios ---
echo ""
echo "1/9 Configurando repositorios (contrib non-free non-free-firmware)..."

# Formato clásico sources.list
if [ -f /etc/apt/sources.list ]; then
    sed -i -E "s/(\b$OS_CODENAME\b\s+)(main|contrib|non-free|non-free-firmware\s*)+/\1main contrib non-free non-free-firmware/g" /etc/apt/sources.list
    sed -i -E "s/(\b$OS_CODENAME-updates\b\s+)(main|contrib|non-free|non-free-firmware\s*)+/\1main contrib non-free non-free-firmware/g" /etc/apt/sources.list
    sed -i -E "s/(\b$OS_CODENAME-security\b\s+)(main|contrib|non-free|non-free-firmware\s*)+/\1main contrib non-free non-free-firmware/g" /etc/apt/sources.list
fi

# Formato DEB822 debian.sources (Debian 12+ por defecto)
if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    # Asegurar Components: main contrib non-free non-free-firmware (idempotente)
    if grep -q "^Components:" /etc/apt/sources.list.d/debian.sources; then
        sed -i -E "s/^Components:.*/Components: main contrib non-free non-free-firmware/" /etc/apt/sources.list.d/debian.sources
    fi
    echo "-> debian.sources parcheado para contrib/non-free"
fi
# También parchear cualquier otro .sources con Suites: trixie/forky
for src in /etc/apt/sources.list.d/*.sources; do
    [ -f "$src" ] || continue
    # Solo tocar si es del codename actual y tiene Components:
    if grep -q "Suites:.*$OS_CODENAME" "$src" 2>/dev/null && grep -q "^Components:" "$src"; then
        sed -i -E "s/^Components:.*/Components: main contrib non-free non-free-firmware/" "$src" || true
    fi
done

if [ "$OS_CODENAME" = "trixie" ]; then
    BACKPORTS_FILE="/etc/apt/sources.list.d/trixie-backports.list"
    cat > "$BACKPORTS_FILE" <<EOF
deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
EOF
    echo "-> Backports asegurado para Trixie"
fi

apt-get update

# --- 2. Hardware y drivers ---
echo ""
echo "2/9 Detectando hardware..."

if grep -qi "GenuineIntel" /proc/cpuinfo; then
    apt-get install -y intel-microcode || true
elif grep -qi "AuthenticAMD" /proc/cpuinfo; then
    apt-get install -y amd64-microcode || true
fi

GPU_TYPE="generic"
if lspci 2>/dev/null | grep -iq "nvidia"; then
    apt-get install -y nvidia-driver nvidia-vaapi-driver libva-nvidia-driver || true
    GPU_TYPE="nvidia"
elif lspci 2>/dev/null | grep -iq "amd.*\(vga\|display\|graphics\)\|Advanced Micro Devices" ; then
    apt-get install -y mesa-va-drivers mesa-vdpau-drivers libgl1-mesa-dri va-driver-all || true
    GPU_TYPE="amd"
elif lspci 2>/dev/null | grep -iq "intel.*\(graphics\|display\|vga\)"; then
    apt-get install -y intel-media-va-driver-non-free libgl1-mesa-dri va-driver-all || true
    GPU_TYPE="intel"
fi
apt-get install -y firmware-linux-nonfree || true

# --- 3. Paquetes base e interfaz ---
echo ""
echo "3/9 Instalando herramientas base + comforts GNOME + Waybar..."

apt-get install -y --no-install-recommends \
    wget curl bc jq build-essential pkg-config unzip \
    network-manager network-manager-gnome iw wireless-tools rfkill \
    gvfs gvfs-backends gvfs-fuse gvfs-daemons udisks2 udiskie \
    nautilus gnome-sushi file-roller \
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
    polkitd pkexec qt6-wayland \
    waybar

# --- 3b. Corregir WiFi unmanaged (dhcpcd/ifupdown -> NetworkManager) ---
echo "-> Corrigiendo WiFi para NetworkManager (unmanaged -> managed)..."
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf <<'NMCONF'
[keyfile]
unmanaged-devices=none
NMCONF
# Forzar managed=true en NetworkManager.conf (si existe)
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    sed -i -E "s/managed=false/managed=true/" /etc/NetworkManager/NetworkManager.conf || true
    grep -q "^\[ifupdown\]" /etc/NetworkManager/NetworkManager.conf || echo -e "\n[ifupdown]\nmanaged=true" >> /etc/NetworkManager/NetworkManager.conf
fi
# Dejar /etc/network/interfaces solo con loopback para que NM gestione wifi/eth
if [ -f /etc/network/interfaces ] && grep -qE "wlp|wlan|eth|enp|ens" /etc/network/interfaces 2>/dev/null; then
    cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s)
    cat > /etc/network/interfaces <<'IFACE'
auto lo
iface lo inet loopback
IFACE
    echo "-> /etc/network/interfaces reseteado a solo lo (backup creado)"
fi
# Evitar que dhcpcd interfiera con NM (denyinterfaces si dhcpcd existe)
if [ -f /etc/dhcpcd.conf ] && ! grep -q "denyinterfaces" /etc/dhcpcd.conf 2>/dev/null; then
    echo "denyinterfaces wlan* wlp* eth* enp* ens*" >> /etc/dhcpcd.conf || true
fi
systemctl enable NetworkManager 2>/dev/null || true
systemctl restart NetworkManager 2>/dev/null || true

if [ "$OS_CODENAME" = "trixie" ]; then
    apt-get install -y -t trixie-backports --no-install-recommends xdg-desktop-portal-hyprland || true
else
    apt-get install -y --no-install-recommends xdg-desktop-portal-hyprland || true
fi

systemctl enable bluetooth || true

# Nautilus: forzar directorios en español y recargar (ejecutar tras instalar nautilus)
sudo -u "$REAL_USER" env HOME="$USER_HOME" LANG=es_ES.UTF-8 xdg-user-dirs-update --force || true
sudo -u "$REAL_USER" env HOME="$USER_HOME" bash -c 'nautilus -q 2>/dev/null || true' || true

# --- 4. Hyprland stack ---
echo ""
echo "4/9 Instalando Hyprland..."

if [ "$OS_CODENAME" = "trixie" ]; then
    apt-get install -y -t trixie-backports --no-install-recommends \
        hyprland hyprlock hypridle hyprpolkitagent hyprland-guiutils greetd tuigreet
else
    apt-get install -y --no-install-recommends \
        hyprland hyprlock hypridle hyprpolkitagent hyprland-guiutils greetd tuigreet
fi

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
    if sudo -u "$REAL_USER" env HOME="$USER_HOME" wget -q --show-progress -O "$tmpzip" "$url"; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" unzip -o -q "$tmpzip" -d "$dest"
        rm -f "$tmpzip"
    fi
}

[ -z "$(ls -A "$MESLO_DIR" 2>/dev/null)" ] && install_nerd_font "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip" "$MESLO_DIR"
[ -z "$(ls -A "$SYMBOLS_DIR" 2>/dev/null)" ] && install_nerd_font "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip" "$SYMBOLS_DIR"

fc-cache -fv || true
chown -R "$REAL_USER":"$REAL_USER" "$FONT_DIR" || true

# --- 6. Greetd + tuigreet ---
echo ""
echo "6/9 Configurando greetd..."

mkdir -p /etc/greetd
mkdir -p /var/cache/tuigreet
chown -R _greetd: /var/cache/tuigreet || true

ENV_VARS="start-hyprland"
[ "$GPU_TYPE" = "nvidia" ] && ENV_VARS="env LIBVA_DRIVER_NAME=nvidia GBM_BACKEND=nvidia-drm __GLX_VENDOR_LIBRARY_NAME=nvidia WLR_NO_HARDWARE_CURSORS=1 start-hyprland"

cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1
[default_session]
command = "/usr/bin/tuigreet --time --remember --asterisks --cmd '$ENV_VARS'"
user = "_greetd"
EOF

usermod -aG video,render _greetd || true
usermod -aG video,render,input "$REAL_USER" || true

mkdir -p /etc/systemd/system/greetd.service.d/
cat > /etc/systemd/system/greetd.service.d/override.conf <<EOF
[Service]
Restart=always
RestartSec=5
EOF
systemctl daemon-reload

# --- 7. Despliegue de configuraciones (dots) ---
echo ""
echo "7/9 Desplegando configuraciones en $USER_HOME/.config..."

DOTS_CONF="$USER_HOME/.config"
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$DOTS_CONF/hypr" "$DOTS_CONF/waybar/themes" "$DOTS_CONF/waybar/scripts"

for src in "hyprland.conf" "hyprlock.conf" "hypridle.conf" "wallpaper.jpg" "power_menu.sh"; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
    fi
done

# Helpers Hyprland / Waybar (scripts que usa waybar y binds)
for src in "waybar_network.sh" "wifi_click.sh" "check_updates.sh" "check_updates_count.sh" "confirm_power.sh" "foot_sync.sh" "power_menu.sh"; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" chmod +x "$DOTS_CONF/hypr/$src" 2>/dev/null || true
    fi
done

# Desplegar Waybar (desde waybar/ subdirectorio)
if [ -d "$SCRIPT_DIR/waybar" ]; then
    if [ -f "$SCRIPT_DIR/waybar/config.jsonc" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/waybar/config.jsonc" "$DOTS_CONF/waybar/config.jsonc"
        # Waybar lee 'config' (sin extensión) también; copiar ambas para compatibilidad
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
        sudo -u "$REAL_USER" env HOME="$USER_HOME" chmod +x "$DOTS_CONF/waybar/scripts/$(basename "$sh")"
    done
    # Sincronizar tema inicial
    if [ -x "$DOTS_CONF/waybar/scripts/waybar-theme.sh" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" bash -c "\"$DOTS_CONF/waybar/scripts/waybar-theme.sh\" || true" || true
    fi
else
    echo "WARN: No se encontró $SCRIPT_DIR/waybar, se omite despliegue Waybar"
fi

# Foot / Fuzzel — despliegue de plantillas (ahora existen en repo)
for app in foot fuzzel; do
    if [ -f "$SCRIPT_DIR/$app.ini" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$DOTS_CONF/$app"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$app.ini" "$DOTS_CONF/$app/$app.ini"
        echo "-> $app.ini desplegado en $DOTS_CONF/$app/"
    fi
done
# Sincronizar Foot/Fuzzel con tema Waybar activo (translúcido e6)
if [ -x "$DOTS_CONF/hypr/foot_sync.sh" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" bash -c "\"$DOTS_CONF/hypr/foot_sync.sh\" || true" || true
fi

# SwayNC
SWAYNC_DIR="$DOTS_CONF/swaync"
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$SWAYNC_DIR"
if [ -f "$SCRIPT_DIR/swaync_config.json" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/swaync_config.json" "$SWAYNC_DIR/config.json"
fi
if [ -f "$SCRIPT_DIR/swaync_style.css" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/swaync_style.css" "$SWAYNC_DIR/style.css"
fi

# Sanitizar hardcodes /home/... -> $USER_HOME en dots desplegados
find "$DOTS_CONF/hypr" "$DOTS_CONF/waybar" "$DOTS_CONF/swaync" -type f \( -name "*.sh" -o -name "*.jsonc" -o -name "config" -o -name "*.conf" -o -name "*.css" -o -name "*.ini" \) \
    -exec sed -i -E "s|/home/[^/]+|$USER_HOME|g" {} + 2>/dev/null || true

chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
chmod +x "$DOTS_CONF/waybar/scripts"/*.sh 2>/dev/null || true

# --- 7b. Fix Zoom Wayland sin XWayland (evita instalar xwayland que rompe Hyprland) ---
echo ""
echo "7b/9 Configurando Zoom para Wayland nativo (sin XWayland)..."

# Wrapper que fuerza wayland + LANG + LD_LIBRARY_PATH (Zoom trae Qt bundled en /opt/zoom/Qt/lib)
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$USER_HOME/.local/bin" "$USER_HOME/.local/share/applications"
sudo -u "$REAL_USER" env HOME="$USER_HOME" bash -c "cat > \"$USER_HOME/.local/bin/zoom-wayland\" <<'ZWAYLAND'
#!/bin/bash
export QT_QPA_PLATFORM=wayland
export LANG=es_AR.UTF-8
export LC_ALL=es_AR.UTF-8
export LD_LIBRARY_PATH=/opt/zoom:/opt/zoom/Qt/lib:/opt/zoom/cef:\$LD_LIBRARY_PATH
exec /opt/zoom/zoom \"\$@\"
ZWAYLAND
"
sudo -u "$REAL_USER" env HOME="$USER_HOME" chmod +x "$USER_HOME/.local/bin/zoom-wayland"

# Desktop override para que el menú use el wrapper y no /usr/bin/zoom (ZoomLauncher -> xcb)
if [ -f /usr/share/applications/Zoom.desktop ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f /usr/share/applications/Zoom.desktop "$USER_HOME/.local/share/applications/Zoom.desktop"
    sudo -u "$REAL_USER" env HOME="$USER_HOME" sed -i -E "s|^Exec=.*zoom.*|Exec=$USER_HOME/.local/bin/zoom-wayland %U|" "$USER_HOME/.local/share/applications/Zoom.desktop"
    sudo -u "$REAL_USER" env HOME="$USER_HOME" update-desktop-database "$USER_HOME/.local/share/applications" 2>/dev/null || true
fi

# Fix hyprpolkitagent: requiere qt6-wayland y QT_QPA_PLATFORM con fallback wayland;xcb (evita crash Qt sin plugin wayland)
if grep -q "env = QT_QPA_PLATFORM,wayland$" "$DOTS_CONF/hypr/hyprland.conf" 2>/dev/null; then
    sed -i -E "s/env = QT_QPA_PLATFORM,wayland$/env = QT_QPA_PLATFORM,wayland;xcb/" "$DOTS_CONF/hypr/hyprland.conf"
    chown "$REAL_USER":"$REAL_USER" "$DOTS_CONF/hypr/hyprland.conf"
    echo "-> hyprland.conf: QT_QPA_PLATFORM corregido a wayland;xcb (fix hyprpolkitagent qt6-wayland)"
fi
grep -q "env = LANG," "$DOTS_CONF/hypr/hyprland.conf" || sed -i "/QT_QPA_PLATFORM/a env = LANG,es_AR.UTF-8" "$DOTS_CONF/hypr/hyprland.conf"
# Asegurar autostart polkit con import-environment (requerido para WAYLAND_DISPLAY en systemd user)
if ! grep -q "import-environment.*QT_QPA_PLATFORM" "$DOTS_CONF/hypr/hyprland.conf" 2>/dev/null; then
    # eliminar posibles líneas viejas sin QT_QPA_PLATFORM para evitar duplicados
    sed -i "/exec-once = systemctl --user import-environment/d" "$DOTS_CONF/hypr/hyprland.conf"
    sed -i "/exec-once = dbus-update-activation-environment.*WAYLAND_DISPLAY/d" "$DOTS_CONF/hypr/hyprland.conf"
    # insertar las dos líneas correctas antes del start hyprpolkitagent
    sed -i "s|exec-once = systemctl --user start hyprpolkitagent|exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORM\n\exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORM\n\0|" "$DOTS_CONF/hypr/hyprland.conf"
    chown "$REAL_USER":"$REAL_USER" "$DOTS_CONF/hypr/hyprland.conf"
    echo "-> hyprland.conf: autostart polkit corregido (import-environment + dbus-update)"
fi
# Eliminar duplicados de hyprpolkitagent si existieran (bug previo)
if [ "$(grep -c "systemctl --user start hyprpolkitagent" "$DOTS_CONF/hypr/hyprland.conf")" -gt 1 ]; then
    awk 'BEGIN{c=0} /systemctl --user start hyprpolkitagent/{c++; if(c>1) next}1' "$DOTS_CONF/hypr/hyprland.conf" > /tmp/hyprland.tmp && cat /tmp/hyprland.tmp > "$DOTS_CONF/hypr/hyprland.conf"
    chown "$REAL_USER":"$REAL_USER" "$DOTS_CONF/hypr/hyprland.conf"
    echo "-> hyprland.conf: duplicado hyprpolkitagent eliminado"
fi

# --- 8. PAM keyring y Portales ---
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

# --- 9. Servicios ---
echo ""
echo "9/9 Habilitando servicios..."

systemctl disable sddm lightdm gdm gdm3 getty@tty1.service 2>/dev/null || true
if systemctl is-enabled greetd &>/dev/null; then
    systemctl mask getty@tty1.service 2>/dev/null || true
fi
systemctl enable greetd

echo ""
echo "--- DIAGNÓSTICO FINAL ---"
echo "Sistema: Debian $OS_CODENAME"
echo "Waybar instalado: $(command -v waybar &>/dev/null && waybar --version 2>&1 | head -n1 || echo 'No')"
echo "Hyprland instalado: $(command -v Hyprland &>/dev/null && Hyprland --version 2>&1 | head -n1 || echo 'No')"
echo "-------------------------------------------------------"
echo "¡INSTALACIÓN COMPLETADA!"
if [ "$GPU_TYPE" = "nvidia" ]; then
    echo "AVISO NVIDIA: añade 'nvidia-drm.modeset=1' a GRUB_CMDLINE_LINUX en /etc/default/grub y ejecuta: update-grub"
fi
echo "Reinicia: sudo reboot"
