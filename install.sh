#!/bin/bash
# =============================================================================
#  Hyprland & Eww Installer - Debian 13 (trixie) - Instalación Limpia
#  Diseñado para: Debian 13 netinst MINIMAL sin entorno gráfico
#  Resultado: Hyprland + Nautilus + GNOME comforts (sin Mutter/GNOME Shell)
#  Autor: JoseloFlores/hypr — optimizado hardware real (Intel/AMD/NVIDIA)
# =============================================================================
# Decisiones integradas (usuario 2026-08-27):
#  - File manager: Nautilus solo (no thunar)
#  - Barra: eww + solar-dashboard (no waybar)
#  - Notificaciones: sway-notification-center + gnome-calendar
#  - Polkit: hyprpolkitagent (no polkit-gnome deprecado)
#  - Navegador: firefox-esr (chrome manual)
#  - zsh solo (sin oh-my-zsh, sin chsh)
#  - Fonts: Meslo Nerd + JetBrainsMono + Nerd Symbols (apt + descarga)
#  - Bluetooth habilitado + PAM gnome-keyring auto-unlock
#  - Repo plano (todo en raíz)
# =============================================================================

set -eo pipefail

# --- Logging ---
LOG_FILE="install.log"
# Si se ejecuta con sudo, el log queda en SCRIPT_DIR no en /root
SCRIPT_DIR_TMP=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LOG_FILE="$SCRIPT_DIR_TMP/install.log"
exec > >(tee -i "$LOG_FILE") 2>&1

echo "=== Hyprland Installer — Debian 13 (trixie) — $(date) ==="

# --- 0. Validaciones ---
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Ejecuta con sudo: sudo ./install.sh" >&2
    exit 1
fi
if [ -z "${SUDO_USER:-}" ]; then
    echo "ERROR: SUDO_USER vacío. Ejecuta con sudo, no como root directo." >&2
    exit 1
fi
REAL_USER=$SUDO_USER
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
if [ ! -d "$USER_HOME" ]; then
    echo "ERROR: No se encontró HOME para $REAL_USER" >&2
    exit 1
fi
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CPU_CORES=$(nproc)
echo "-> Usuario: $REAL_USER | HOME: $USER_HOME | Cores: $CPU_CORES | Repo: $SCRIPT_DIR"

# Verificar conectividad mínima
if ! ping -c1 -W3 deb.debian.org &>/dev/null; then
    echo "ADVERTENCIA: Sin conectividad a deb.debian.org — intentando continuar..."
fi

# --- 1. Repositorios (trixie + backports) ---
echo ""
echo "1/10 Configurando repositorios (contrib non-free non-free-firmware)..."
BACKPORTS_FILE="/etc/apt/sources.list.d/trixie-backports.list"
# Crear/asegurar backports con todos los componentes
cat > "$BACKPORTS_FILE" <<EOF
deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
EOF
echo "-> Backports asegurado en $BACKPORTS_FILE"

if [ -f /etc/apt/sources.list ]; then
    echo "-> Normalizando /etc/apt/sources.list (idempotente)..."
    # Añade contrib non-free non-free-firmware a trixie, trixie-updates y trixie-security
    sed -i -E 's/(\btrixie\b\s+)(main|contrib|non-free|non-free-firmware\s*)+/\1main contrib non-free non-free-firmware/g' /etc/apt/sources.list
    sed -i -E 's/(\btrixie-updates\b\s+)(main|contrib|non-free|non-free-firmware\s*)+/\1main contrib non-free non-free-firmware/g' /etc/apt/sources.list
    sed -i -E 's/(\btrixie-security\b\s+)(main|contrib|non-free|non-free-firmware\s*)+/\1main contrib non-free non-free-firmware/g' /etc/apt/sources.list
else
    echo "-> /etc/apt/sources.list no existe, se usa solo backports fragment"
fi

# No tocar otros .list/.sources (brave, chrome, spotify, tailscale, vscode) — usuario los gestiona manual
echo "-> Repositorios externos en sources.list.d se dejan intactos."

apt-get update

# --- 2. Hardware y drivers ---
echo ""
echo "2/10 Detectando hardware..."

# CPU microcode
if grep -qi "GenuineIntel" /proc/cpuinfo; then
    echo "-> CPU Intel detectada → intel-microcode"
    apt-get install -y intel-microcode || echo "WARN: intel-microcode falló"
elif grep -qi "AuthenticAMD" /proc/cpuinfo; then
    echo "-> CPU AMD detectada → amd64-microcode"
    apt-get install -y amd64-microcode || echo "WARN: amd64-microcode falló"
fi

# GPU
GPU_TYPE="generic"
if lspci 2>/dev/null | grep -iq "nvidia"; then
    echo "-> GPU NVIDIA → nvidia-driver + vaapi"
    apt-get install -y nvidia-driver nvidia-vaapi-driver libva-nvidia-driver || echo "WARN: nvidia-driver falló"
    GPU_TYPE="nvidia"
elif lspci 2>/dev/null | grep -iq "amd.*\(vga\|display\|graphics\)\|Advanced Micro Devices" ; then
    # lspci en AMD Sanchez es ambiguo, segundo check por si es solo 'amd' genérico
    echo "-> GPU AMD → mesa"
    apt-get install -y mesa-va-drivers mesa-vdpau-drivers libgl1-mesa-dri va-driver-all || true
    GPU_TYPE="amd"
elif lspci 2>/dev/null | grep -iq "intel.*\(graphics\|display\|vga\)"; then
    echo "-> GPU Intel → intel-media-va-driver-non-free"
    apt-get install -y intel-media-va-driver-non-free libgl1-mesa-dri va-driver-all || true
    GPU_TYPE="intel"
else
    # Fallback genérico pero intenta detectar AMD simple
    if lspci 2>/dev/null | grep -iq "amd"; then
        echo "-> GPU AMD (fallback) → mesa"
        apt-get install -y mesa-va-drivers mesa-vdpau-drivers libgl1-mesa-dri va-driver-all || true
        GPU_TYPE="amd"
    elif lspci 2>/dev/null | grep -iq "intel"; then
        echo "-> GPU Intel (fallback)"
        apt-get install -y intel-media-va-driver-non-free libgl1-mesa-dri va-driver-all || true
        GPU_TYPE="intel"
    else
        echo "-> GPU genérica/VM → mesa genérico"
        apt-get install -y libgl1-mesa-dri va-driver-all || true
    fi
fi
# Firmware común siempre útil en hardware real
apt-get install -y firmware-linux-nonfree || echo "WARN: firmware-linux-nonfree no disponible/ya instalado"

# --- 3. Paquetes base (GNOME comforts sin Mutter/GNOME Shell) ---
echo ""
echo "3/10 Instalando herramientas base + comforts GNOME..."

# Nota: --no-install-recommends para evitar arrastrar gnome-shell/mutter
# Se excluye thunar (usuario eligió solo nautilus)
apt-get install -y --no-install-recommends \
    wget curl bc jq git build-essential pkg-config unzip \
    network-manager nm-connection-editor \
    gvfs gvfs-backends gvfs-fuse gvfs-daemons udisks2 udiskie \
    nautilus gnome-sushi file-roller \
    pipewire pipewire-alsa pipewire-audio pipewire-pulse wireplumber \
    pavucontrol \
    bluez blueman \
    sway-notification-center gnome-calendar \
    wl-clipboard cliphist brightnessctl playerctl \
    foot fuzzel swaybg grim slurp swappy wf-recorder \
    xdg-desktop-portal xdg-desktop-portal-gtk \
    zsh vim firefox-esr zenity lxappearance \
    fonts-jetbrains-mono fonts-noto-color-emoji \
    gnome-keyring libpam-gnome-keyring seahorse \
    polkitd

# xdg-desktop-portal-hyprland viene de backports
apt-get install -y -t trixie-backports --no-install-recommends \
    xdg-desktop-portal-hyprland || echo "WARN: xdg-desktop-portal-hyprland no instalado (revisar backports)"

# Bluetooth: habilitar servicio (firmware ya arriba)
if systemctl list-unit-files | grep -q "^bluetooth.service"; then
    systemctl enable bluetooth || echo "WARN: no se pudo enable bluetooth"
fi

# --- 4. Hyprland stack (backports) ---
echo ""
echo "4/10 Instalando Hyprland (backports)..."

apt-get install -y -t trixie-backports --no-install-recommends \
    hyprland hyprlock hypridle hyprpolkitagent greetd

# tuigreet (puede estar en trixie main o backports según mirror)
if ! command -v tuigreet &>/dev/null; then
    echo "-> Instalando tuigreet..."
    apt-get install -y tuigreet || apt-get install -y -t trixie-backports tuigreet || echo "WARN: tuigreet no encontrado"
fi

# --- 5. Fuentes: Meslo Nerd + JetBrainsMono (apt) + Nerd Symbols ---
echo ""
echo "5/10 Instalando fuentes (JetBrainsMono apt + Meslo/Nerd Symbols descarga)..."

# JetBrainsMono ya instalado vía apt arriba (fonts-jetbrains-mono)
# Meslo Nerd Font + Symbols Nerd Font via descarga directa (repo ligero, no subir zips)
FONT_DIR="$USER_HOME/.local/share/fonts"
MESLO_DIR="$FONT_DIR/Meslo"
SYMBOLS_DIR="$FONT_DIR/NerdSymbols"

sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$MESLO_DIR" "$SYMBOLS_DIR"

# Función helper: descargar y descomprimir fuente
install_nerd_font() {
    local url="$1"
    local dest="$2"
    local tmpzip="/tmp/$(basename "$dest").zip"
    echo "-> Descargando $(basename "$url")..."
    if sudo -u "$REAL_USER" env HOME="$USER_HOME" wget -q --show-progress -O "$tmpzip" "$url"; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" unzip -o -q "$tmpzip" -d "$dest" || echo "WARN: unzip falló para $url"
        rm -f "$tmpzip"
    else
        echo "WARN: No se pudo descargar $url (sin internet o URL cambiada)"
    fi
}

# Meslo (ryanoasis/nerd-fonts latest)
if [ -z "$(ls -A "$MESLO_DIR" 2>/dev/null)" ]; then
    install_nerd_font "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip" "$MESLO_DIR"
else
    echo "-> Meslo ya existe en $MESLO_DIR, se omite descarga"
fi

# SymbolsOnly para iconos (material, codicons, etc.) — liviano, complementa JetBrainsMono
if [ -z "$(ls -A "$SYMBOLS_DIR" 2>/dev/null)" ]; then
    install_nerd_font "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip" "$SYMBOLS_DIR"
else
    echo "-> Nerd Symbols ya existe en $SYMBOLS_DIR"
fi

# Refrescar caché
fc-cache -fv || true
# Permisos fuentes al usuario
chown -R "$REAL_USER":"$REAL_USER" "$FONT_DIR" || true

echo "-> Fuentes instaladas: JetBrainsMono (apt) + Meslo + Symbols (descarga)"

# --- 6. Eww (compilación) ---
echo ""
echo "6/10 Preparando Eww (barra)..."
apt-get install -y -t trixie-backports --no-install-recommends \
    rustc cargo libgtk-3-dev libgtk-layer-shell-dev \
    libpangocairo-1.0-0 libcairo-gobject2 libglib2.0-dev libgdk-pixbuf-2.0-dev \
    libpango1.0-dev libdbus-1-dev libssl-dev libcairo2-dev \
    libdbusmenu-gtk3-dev libdbusmenu-glib-dev || echo "WARN: deps Eww fallaron parcialmente"

if [ ! -f "/usr/local/bin/eww" ]; then
    echo "-> Clonando y compilando Eww ($CPU_CORES hilos, puede tardar 5-10 min)..."
    EWW_BUILD_DIR="/tmp/eww_build"
    rm -rf "$EWW_BUILD_DIR"
    if sudo -u "$REAL_USER" env HOME="$USER_HOME" git clone --depth 1 https://github.com/elkowar/eww "$EWW_BUILD_DIR"; then
        cd "$EWW_BUILD_DIR"
        if ! sudo -u "$REAL_USER" env HOME="$USER_HOME" cargo build --release --no-default-features --features wayland -j "$CPU_CORES"; then
            echo "ERROR: Falló compilación Eww" >&2
            exit 1
        fi
        mkdir -p /usr/local/bin
        cp target/release/eww /usr/local/bin/
        echo "-> eww instalado en /usr/local/bin/eww"
        cd "$SCRIPT_DIR"
        rm -rf "$EWW_BUILD_DIR"
    else
        echo "ERROR: No se pudo clonar eww" >&2
        exit 1
    fi
else
    echo "-> eww ya existe en /usr/local/bin/eww, se omite compilación"
fi

# --- 7. Greetd + tuigreet ---
echo ""
echo "7/10 Configurando greetd..."

mkdir -p /etc/greetd
mkdir -p /var/cache/tuigreet
chown -R _greetd:_greetd /var/cache/tuigreet || chown -R _greetd:greetd /var/cache/tuigreet || true

ENV_VARS="start-hyprland"
if [ "$GPU_TYPE" = "nvidia" ]; then
    ENV_VARS="env LIBVA_DRIVER_NAME=nvidia GBM_BACKEND=nvidia-drm __GLX_VENDOR_LIBRARY_NAME=nvidia WLR_NO_HARDWARE_CURSORS=1 start-hyprland"
fi

cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet --time --remember --asterisks --cmd '$ENV_VARS'"
user = "_greetd"
EOF

usermod -aG video,render _greetd || true
# Asegurar grupos del usuario real para video/render/input
usermod -aG video,render,input "$REAL_USER" || true

mkdir -p /etc/systemd/system/greetd.service.d/
cat > /etc/systemd/system/greetd.service.d/override.conf <<EOF
[Service]
Restart=always
RestartSec=5
EOF
systemctl daemon-reload

# --- 8. Despliegue de configuraciones (dots) ---
echo ""
echo "8/10 Desplegando configuraciones en $USER_HOME/.config..."

DOTS_CONF="$USER_HOME/.config"
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$DOTS_CONF"

# Mapeo archivos planos del repo → destino
# El repo es plano: hyprland.conf, hyprlock.conf, hypridle.conf, wallpaper.jpg, *.sh
declare -A DOT_FILES=(
    ["hyprland.conf"]="hypr/hyprland.conf"
    ["hyprlock.conf"]="hypr/hyprlock.conf"
    ["hypridle.conf"]="hypr/hypridle.conf"
    ["wallpaper.jpg"]="hypr/wallpaper.jpg"
)

# Crear ~/.config/hypr y copiar
HYPR_DIR="$DOTS_CONF/hypr"
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$HYPR_DIR"
for src in "hyprland.conf" "hyprlock.conf" "hypridle.conf" "wallpaper.jpg"; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        echo "-> Copiando $src → $HYPR_DIR/"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$HYPR_DIR/"
    fi
done

# Scripts del repo → ~/.config/hypr/
for sh in eww_start.sh eww_restart.sh foot_sync.sh power_menu.sh confirm_power.sh eww_network.sh check_updates.sh check_updates_count.sh; do
    if [ -f "$SCRIPT_DIR/$sh" ]; then
        echo "-> Copiando $sh → $HYPR_DIR/"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$sh" "$HYPR_DIR/"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" chmod +x "$HYPR_DIR/$sh"
    fi
done

# foot y fuzzel: si existen como archivos planos con nombre foot.ini / fuzzel.ini o carpetas
# Por ahora: si el repo trae archivos foot*/fuzzel* copiar; si no, crear estructura mínima
if [ -f "$SCRIPT_DIR/foot.ini" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$DOTS_CONF/foot"
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/foot.ini" "$DOTS_CONF/foot/foot.ini"
fi
if [ -f "$SCRIPT_DIR/fuzzel.ini" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$DOTS_CONF/fuzzel"
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/fuzzel.ini" "$DOTS_CONF/fuzzel/fuzzel.ini"
fi

# Eww config: clonar tema de JoseloFlores/eww (barras)
if [ ! -d "$DOTS_CONF/eww" ]; then
    echo "-> Clonando tema Eww (JoseloFlores/eww)..."
    sudo -u "$REAL_USER" env HOME="$USER_HOME" git clone --depth 1 https://github.com/JoseloFlores/eww "$DOTS_CONF/eww" || echo "WARN: No se pudo clonar eww theme"
else
    echo "-> ~/.config/eww ya existe, se omite clonado"
fi

# SwayNC: desplegar config con calendario + integración eww
SWAYNC_DIR="$DOTS_CONF/swaync"
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$SWAYNC_DIR"
# Si el repo trae swaync_config.json / swaync_style.css planos, úsalos
if [ -f "$SCRIPT_DIR/swaync_config.json" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/swaync_config.json" "$SWAYNC_DIR/config.json"
elif [ ! -f "$SWAYNC_DIR/config.json" ]; then
    echo "-> Creando swaync config.json por defecto (con calendar)..."
    sudo -u "$REAL_USER" env HOME="$USER_HOME" bash -c "cat > \"$SWAYNC_DIR/config.json\" <<'SWAYNC_JSON'
{
  \"positionX\": \"right\",
  \"positionY\": \"top\",
  \"layer\": \"overlay\",
  \"control-center-width\": 380,
  \"control-center-height\": 860,
  \"cssPriority\": \"user\",
  \"notification-window-width\": 380,
  \"timeout\": 6,
  \"timeout-low\": 3,
  \"timeout-critical\": 0,
  \"fit-to-screen\": true,
  \"keyboard-shortcuts\": true,
  \"image-visibility\": \"when-available\",
  \"transition-time\": 200,
  \"hide-on-clear\": false,
  \"hide-on-action\": true,
  \"script-fail-notify\": true,
  \"widgets\": [\"title\", \"dnd\", \"calendar\", \"notifications\"],
  \"widget-config\": {
    \"title\": { \"text\": \"Notificaciones\", \"clear-all-button\": true, \"button-text\": \"Limpiar\" },
    \"dnd\": { \"text\": \"No molestar\" },
    \"calendar\": { \"label\": \"\", \"position\": \"top\" },
    \"mpris\": { \"image-size\": 96, \"image-radius\": 6 }
  }
}
SWAYNC_JSON"
fi

if [ -f "$SCRIPT_DIR/swaync_style.css" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/swaync_style.css" "$SWAYNC_DIR/style.css"
elif [ ! -f "$SWAYNC_DIR/style.css" ]; then
    # Si sway-notification-center está instalado, copiar base de /etc/xdg como fallback
    if [ -f "/etc/sway-notification-center/config.json" ]; then
        echo "-> Usando style.css base de sway-notification-center si existe"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f /etc/sway-notification-center/style.css "$SWAYNC_DIR/style.css" 2>/dev/null || true
    fi
    # Si aún no hay style.css, crear uno mínimo oscuro
    if [ ! -f "$SWAYNC_DIR/style.css" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" bash -c "cat > \"$SWAYNC_DIR/style.css\" <<'SWAYNC_CSS'
/* swaync style mínimo — el tema eww define colores reales */
.notification-row { margin: 6px; }
SWAYNC_CSS"
    fi
fi

# --- 9. Permisos, rutas y PAM keyring ---
echo ""
echo "9/10 Finalizando permisos, rutas y PAM..."

# Compatibilidad: symlink legacy /home/jose/eww/target/release/eww
mkdir -p "$USER_HOME/eww/target/release"
ln -sf /usr/local/bin/eww "$USER_HOME/eww/target/release/eww"
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/eww" 2>/dev/null || true

# Corregir hardcode /home/jose residual en configs desplegadas (por si el tema eww lo trae)
find "$DOTS_CONF" -type f \( -name "*.sh" -o -name "*.yuck" -o -name "*.conf" -o -name "*.scss" \) \
    -exec sed -i "s|/home/jose|$USER_HOME|g" {} + 2>/dev/null || true
# Asegurar eww usa /usr/local/bin/eww y no ruta legacy
sed -i "s|/home/[^/]*/eww/target/release/eww|/usr/local/bin/eww|g" "$HYPR_DIR/eww_start.sh" "$HYPR_DIR/eww_restart.sh" 2>/dev/null || true
# Normalizar permisos
chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
chmod +x "$HYPR_DIR"/*.sh 2>/dev/null || true

# PAM gnome-keyring: habilitar vía pam-auth-update si existe, si no editar manual
if command -v pam-auth-update &>/dev/null; then
    echo "-> Habilitando pam_gnome_keyring vía pam-auth-update..."
    pam-auth-update --enable gnome-keyring || echo "WARN: pam-auth-update falló, se intenta manual"
fi
# Fallback manual: asegurar que common-auth/common-session/common-password incluyan pam_gnome_keyring
# pam-auth-update ya lo hace, pero por si acaso se verifica
if ! grep -q "pam_gnome_keyring.so" /etc/pam.d/common-auth 2>/dev/null; then
    echo "-> Añadiendo pam_gnome_keyring a common-auth (fallback)..."
    # Se deja a pam-auth-update; no forzar edición manual para no romper
    echo "   Ejecuta: sudo pam-auth-update y activa 'GNOME Keyring Daemon'"
fi
# greetd PAM: crear /etc/pam.d/greetd con keyring si no existe
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
    echo "-> /etc/pam.d/greetd creado con gnome-keyring"
else
    if ! grep -q "pam_gnome_keyring" /etc/pam.d/greetd; then
        echo "-> Añadiendo pam_gnome_keyring a /etc/pam.d/greetd existente..."
        sed -i '/@include common-auth/i auth    optional        pam_gnome_keyring.so' /etc/pam.d/greetd
        sed -i '/@include common-session/a session optional        pam_gnome_keyring.so auto_start' /etc/pam.d/greetd
    fi
fi

# Asegurar portal config Hyprland tiene prioridad
mkdir -p /etc/xdg/xdg-desktop-portal
if [ ! -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf ]; then
    cat > /etc/xdg/xdg-desktop-portal/hyprland-portals.conf <<'PORTAL'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
PORTAL
fi

# --- 10. Servicios ---
echo ""
echo "10/10 Habilitando servicios..."

# Deshabilitar DMs que compiten con greetd (no fallar si no existen — netinst limpio no los tiene)
systemctl disable sddm lightdm gdm gdm3 getty@tty1.service 2>/dev/null || true
# Solo enmascarar getty@tty1 si greetd está habilitado (evita dejar sistema sin login)
if systemctl is-enabled greetd &>/dev/null; then
    systemctl mask getty@tty1.service 2>/dev/null || true
fi
systemctl enable greetd
# bluetooth ya enable arriba; asegurar también
systemctl enable bluetooth 2>/dev/null || true
systemctl set-default graphical.target

echo ""
echo "--- DIAGNÓSTICO FINAL ---"
echo "Hardware: CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs) | GPU=$GPU_TYPE"
echo "Greetd: $(systemctl is-enabled greetd 2>&1)"
echo "Bluetooth: $(systemctl is-enabled bluetooth 2>&1)"
echo "Portal: $(systemctl --global is-enabled xdg-desktop-portal-hyprland 2>&1 || echo 'portal sin enable global (normal)')"
echo "Eww: $(/usr/local/bin/eww --version 2>&1 || echo 'eww no en PATH')"
echo "SwayNC: $(command -v swaync &>/dev/null && swaync --version 2>&1 || echo 'swaync no instalado')"
echo "Keyring PAM: $(grep -q pam_gnome_keyring /etc/pam.d/common-auth && echo 'OK' || echo 'revisa pam-auth-update')"
echo "Fuentes: $(fc-list | grep -ci 'Meslo\|JetBrains' || echo 0) familias Nerd detectadas"
echo "-------------------------------------------------------"
echo "¡INSTALACIÓN COMPLETADA!"
if [ "$GPU_TYPE" = "nvidia" ]; then
    echo "AVISO NVIDIA: añade 'nvidia-drm.modeset=1' a GRUB_CMDLINE_LINUX en /etc/default/grub y ejecuta: update-grub"
fi
echo "Reinicia: sudo reboot"
echo "Primer login: greetd → tuigreet → Hyprland (start-hyprland)"
echo "Atajos: Super+Enter (foot), Super+D (fuzzel), Super+L (power), Print (grim+swappy)"
echo "Post-instalación: instala Chrome manualmente si lo deseas."
echo "Log completo: $LOG_FILE"
echo "-------------------------------------------------------"
