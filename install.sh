#!/bin/bash

# =============================================================================
#  Hyprland & Eww Installer - HARDWARE REAL OPTIMIZED (Intel/AMD/NVIDIA)
# =============================================================================

set -eo pipefail

# Configurar logging
LOG_FILE="install.log"
exec > >(tee -i "$LOG_FILE") 2>&1

echo "--- INICIANDO INSTALACIÓN EN HARDWARE REAL ---"

# 1. Validaciones Iniciales
if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: Ejecuta con sudo: sudo ./install.sh"
  exit 1
fi

REAL_USER=$SUDO_USER
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
CPU_CORES=$(nproc)

# 2. Configuración de Repositorios (Debian Trixie)
echo "1/10 Configurando repositorios con Non-Free..."
BACKPORTS_FILE="/etc/apt/sources.list.d/trixie-backports.list"
if [ ! -f "$BACKPORTS_FILE" ]; then
    echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" | tee "$BACKPORTS_FILE"
fi

# Asegurar componentes contrib y non-free en el sources principal de manera idempotente
echo "Configurando componentes contrib, non-free y non-free-firmware..."
if [ -f /etc/apt/sources.list ]; then
    sed -i -E 's/(\btrixie\b\s+)(main|contrib|non-free|non-free-firmware\s*)+/\1main contrib non-free non-free-firmware/g' /etc/apt/sources.list
    sed -i -E 's/(\btrixie-updates\b\s+)(main|contrib|non-free|non-free-firmware\s*)+/\1main contrib non-free non-free-firmware/g' /etc/apt/sources.list
    sed -i -E 's/(\btrixie-security\b\s+)(main|contrib|non-free|non-free-firmware\s*)+/\1main contrib non-free non-free-firmware/g' /etc/apt/sources.list
fi

apt-get update

# 3. Detección de Hardware y Drivers
echo "2/10 Detectando Hardware..."

# Detectar CPU
if grep -q "Intel" /proc/cpuinfo; then
    echo "-> CPU Intel detectada. Instalando microcode..."
    apt-get install -y intel-microcode
elif grep -q "AMD" /proc/cpuinfo; then
    echo "-> CPU AMD detectada. Instalando microcode..."
    apt-get install -y amd64-microcode
fi

# Detectar GPU
GPU_TYPE="generic"
if lspci | grep -iq "nvidia"; then
    echo "-> GPU NVIDIA detectada. Instalando drivers propietarios..."
    apt-get install -y nvidia-driver nvidia-vaapi-driver libva-nvidia-driver
    GPU_TYPE="nvidia"
elif lspci | grep -iq "amd"; then
    echo "-> GPU AMD detectada. Instalando drivers mesa..."
    apt-get install -y mesa-va-drivers mesa-vdpau-drivers libgl1-mesa-dri va-driver-all
    GPU_TYPE="amd"
elif lspci | grep -iq "intel"; then
    echo "-> GPU Intel detectada. Instalando drivers intel..."
    apt-get install -y intel-media-va-driver-non-free libgl1-mesa-dri va-driver-all
    GPU_TYPE="intel"
else
    echo "-> Usando drivers genéricos (Posible VM)..."
    apt-get install -y libgl1-mesa-dri va-driver-all
fi

# 4. Instalación de Paquetes Base
echo "3/10 Instalando herramientas de sistema..."
apt-get install -y --no-install-recommends \
    firmware-linux-nonfree wget curl bc jq git build-essential pkg-config \
    network-manager nm-connection-editor udiskie foot thunar fuzzel \
    playerctl wireplumber brightnessctl grim slurp swappy pavucontrol \
    blueman firefox-esr swaybg zenity zsh vim lxappearance

echo "4/10 Instalando Hyprland (Backports)..."
apt-get install -y -t trixie-backports --no-install-recommends \
    hyprland hyprlock hypridle hyprpolkitagent greetd

# 5. Instalación de tuigreet
if [ ! -f "/usr/bin/tuigreet" ]; then
    echo "Instalando tuigreet..."
    apt-get install -y tuigreet
fi

# 6. Compilación de Eww (Optimizada)
echo "5/10 Preparando Eww..."
# Corregido typo de libgdk-pixbuf-2.0-dev y añadidas dependencias dbusmenu
apt-get install -y -t trixie-backports --no-install-recommends \
    rustc cargo libgtk-3-dev libgtk-layer-shell-dev \
    libpangocairo-1.0-0 libcairo-gobject2 libglib2.0-dev libgdk-pixbuf-2.0-dev \
    libpango1.0-dev libdbus-1-dev libssl-dev libcairo2-dev \
    libdbusmenu-gtk3-dev libdbusmenu-glib-dev

if [ ! -f "/usr/local/bin/eww" ]; then
    echo "Clonando y compilando Eww usando $CPU_CORES núcleos..."
    EWW_BUILD_DIR="/tmp/eww_build"
    rm -rf "$EWW_BUILD_DIR"
    # Añadido env HOME para evitar problemas de permisos de cargo con el directorio root
    sudo -u "$REAL_USER" env HOME="$USER_HOME" git clone --depth 1 https://github.com/elkowar/eww "$EWW_BUILD_DIR"
    cd "$EWW_BUILD_DIR"
    if ! sudo -u "$REAL_USER" env HOME="$USER_HOME" cargo build --release --no-default-features --features wayland -j "$CPU_CORES"; then
        echo "ERROR: Falló la compilación de Eww." >&2
        exit 1
    else
        mkdir -p /usr/local/bin
        cp target/release/eww /usr/local/bin/
    fi
    cd "$SCRIPT_DIR"
fi

# 7. Configuración de Greetd Dinámica
echo "6/10 Configurando Greetd..."
mkdir -p /etc/greetd

# Crear directorio de cache para tuigreet y asignar propietario para evitar fallos con --remember
mkdir -p /var/cache/tuigreet
chown -R _greetd:_greetd /var/cache/tuigreet

# Definir variables de entorno según la GPU para optimizar rendimiento
# Se usa start-hyprland (wrapper de Debian 13) en lugar de dbus-run-session Hyprland
ENV_VARS="start-hyprland"
if [ "$GPU_TYPE" == "nvidia" ]; then
    ENV_VARS="env LIBVA_DRIVER_NAME=nvidia GBM_BACKEND=nvidia-drm __GLX_VENDOR_LIBRARY_NAME=nvidia WLR_NO_HARDWARE_CURSORS=1 start-hyprland"
fi

cat <<EOF > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet --time --remember --asterisks --cmd '$ENV_VARS'"
user = "_greetd"
EOF
usermod -aG video,render _greetd || true

# Override para asegurar que greetd espere a los drivers
mkdir -p /etc/systemd/system/greetd.service.d/
cat <<EOF > /etc/systemd/system/greetd.service.d/override.conf
[Service]
Restart=always
RestartSec=5
EOF
systemctl daemon-reload

# 8. Despliegue de Configuraciones (Dots)
DOTS_CONF="$USER_HOME/.config"
echo "7/10 Desplegando configuraciones en $DOTS_CONF..."
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$DOTS_CONF"

CONFIGS=("hypr" "foot" "fuzzel")
for item in "${CONFIGS[@]}"; do
    TARGET="$DOTS_CONF/$item"
    if [ ! -d "$TARGET" ]; then
        SRC=""
        [ -d "$SCRIPT_DIR/$item" ] && SRC="$SCRIPT_DIR/$item"
        [ -d "$SCRIPT_DIR/../$item" ] && SRC="$SCRIPT_DIR/../$item"
        [ "$(basename "$SCRIPT_DIR")" == "$item" ] && SRC="$SCRIPT_DIR"

        if [ -n "$SRC" ]; then
            echo "Copiando $item desde $SRC..."
            if [ "$SRC" == "$SCRIPT_DIR" ]; then
                sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$TARGET"
                sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -r "$SRC"/* "$TARGET/"
            else
                sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -r "$SRC" "$DOTS_CONF/"
            fi
        fi
    fi
done

# Eww config personalizada
if [ ! -d "$DOTS_CONF/eww" ]; then
    echo "Clonando configuración de Eww..."
    sudo -u "$REAL_USER" env HOME="$USER_HOME" git clone --depth 1 https://github.com/JoseloFlores/eww "$DOTS_CONF/eww" || true
fi

# 9. Permisos y Rutas
echo "8/10 Finalizando permisos y rutas..."

# Creamos la ruta esperada por tus scripts (/home/jose/eww/target/release/eww) como symlink
# para no tener que modificar tus archivos y configuraciones en uso.
mkdir -p "$USER_HOME/eww/target/release"
ln -sf /usr/local/bin/eww "$USER_HOME/eww/target/release/eww"
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/eww"

# Si por alguna razón el usuario tiene un path genérico en otra ruta, lo corregimos en sus configs
find "$DOTS_CONF" -type f \( -name "*.sh" -o -name "*.yuck" -o -name "*.conf" \) -exec sed -i "s|/home/jose|$USER_HOME|g" {} + 2>/dev/null || true

# Optimizado para evitar chown en todo el home directory (que tarda mucho en hardware real)
chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} +

# 10. Servicios
echo "9/10 Habilitando servicios..."
systemctl disable sddm lightdm gdm getty@tty1.service || true
systemctl mask getty@tty1.service || true
systemctl enable greetd
systemctl set-default graphical.target

echo "--- 10/10 DIAGNÓSTICO FINAL ---"
echo "Hardware detectado: CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2) | GPU: $GPU_TYPE"
systemctl is-enabled greetd

echo "-------------------------------------------------------"
echo "¡INSTALACIÓN COMPLETADA PARA HARDWARE REAL!"
if [ "$GPU_TYPE" == "nvidia" ]; then
    echo "AVISO: Se detectó NVIDIA. Asegúrate de añadir 'nvidia-drm.modeset=1'"
    echo "a los parámetros del kernel en /etc/default/grub y ejecutar 'update-grub'."
fi
echo "REINICIA AHORA: 'sudo reboot'"
echo "-------------------------------------------------------"
