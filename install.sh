#!/bin/bash

# =============================================================================
#  Hyprland & Eww Minimal Installer - Debian 13 (Trixie)
# =============================================================================

set -e

# Configurar logging para ver errores después (en el directorio actual)
LOG_FILE="install.log"
exec > >(tee -i "$LOG_FILE") 2>&1

# Comprobación de root
if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: Por favor, ejecuta este script con sudo."
  exit 1
fi

if [ -z "$SUDO_USER" ]; then
  echo "ERROR: No se detectó el usuario real. Ejecuta con 'sudo ./install.sh'."
  exit 1
fi

REAL_USER=$SUDO_USER
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

echo "Iniciando instalación para $REAL_USER en $USER_HOME..."
echo "Los logs se guardarán en $(pwd)/$LOG_FILE"

# 1. Configuración de Repositorios (Asegurar Backports para Hyprland)
echo "--- 1/10 Configurando repositorios ---"
BACKPORTS_FILE="/etc/apt/sources.list.d/trixie-backports.list"
if [ ! -f "$BACKPORTS_FILE" ]; then
    echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" | tee "$BACKPORTS_FILE"
fi
apt update

# 2. Drivers y Firmware
echo "--- 2/10 Instalando drivers de video y firmware ---"
apt install -y --no-install-recommends \
    firmware-linux-nonfree \
    intel-media-va-driver mesa-va-drivers \
    libgl1-mesa-dri xserver-xorg-video-all \
    va-driver-all

# 3. Herramientas Base del Sistema
echo "--- 3/10 Instalando utilidades base ---"
apt install -y --no-install-recommends \
    wget curl bc jq git build-essential pkg-config \
    network-manager nm-connection-editor \
    udiskie foot thunar fuzzel playerctl wireplumber brightnessctl \
    grim slurp swappy pavucontrol blueman firefox-esr \
    swaybg zenity zsh vim lxappearance libpam0g-dev

# 4. Hyprland y Ecosistema (Desde Backports)
echo "--- 4/10 Instalando Hyprland, Greetd y Hypr-herramientas ---"
apt install -y -t trixie-backports --no-install-recommends \
    hyprland hyprlock hypridle hyprpolkitagent

apt install -y --no-install-recommends greetd

# 5. Instalación de tuigreet
if [ ! -f "/usr/bin/tuigreet" ]; then
    echo "--- 5/10 Descargando tuigreet ---"
    TUIGREET_VERSION="0.9.1"
    wget -q "https://github.com/apognu/tuigreet/releases/download/$TUIGREET_VERSION/tuigreet-$TUIGREET_VERSION.tar.gz" -O /tmp/tuigreet.tar.gz
    mkdir -p /tmp/tuigreet_ext
    tar -xzf /tmp/tuigreet.tar.gz -C /tmp/tuigreet_ext
    find /tmp/tuigreet_ext -name tuigreet -type f -exec cp {} /usr/bin/ \;
    chmod +x /usr/bin/tuigreet
    rm -rf /tmp/tuigreet.tar.gz /tmp/tuigreet_ext
fi

# 6. Compilación de Eww
echo "--- 6/10 Instalando dependencias de compilación para Eww ---"
apt install -y --no-install-recommends \
    rustc cargo libgtk-3-dev libgtk-layer-shell-dev \
    libpangocairo-1.0-0 libcairo-gobject2 libglib2.0-dev libgdk-pixbuf2.0-dev \
    libpango1.0-dev libdbus-1-dev libssl-dev

if [ ! -f "/usr/local/bin/eww" ]; then
    echo "Clonando y compilando Eww (esto puede tardar unos minutos)..."
    EWW_BUILD_DIR="/tmp/eww_build"
    rm -rf "$EWW_BUILD_DIR"
    sudo -u "$REAL_USER" git clone https://github.com/elkowar/eww "$EWW_BUILD_DIR"
    cd "$EWW_BUILD_DIR"
    # Compilamos con soporte para Wayland
    if ! sudo -u "$REAL_USER" cargo build --release --no-default-features --features wayland; then
        echo "ERROR: Falló la compilación de Eww. Revisa el log."
    else
        cp target/release/eww /usr/local/bin/
    fi
    cd "$SCRIPT_DIR"
    rm -rf "$EWW_BUILD_DIR"
fi

# 7. Configuración de Greetd (Login ligero con soporte VM)
echo "--- 7/10 Configurando Greetd ---"
mkdir -p /etc/greetd
# Forzamos WLR_NO_HARDWARE_CURSORS para compatibilidad con VMs y algunos drivers
cat <<EOF > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "env WLR_NO_HARDWARE_CURSORS=1 /usr/bin/tuigreet --time --remember --cmd /usr/bin/Hyprland"
user = "_greetd"
EOF
usermod -aG video _greetd || true
usermod -aG render _greetd || true

# 8. Despliegue de Configuraciones (Dots)
DOTS_CONF="$USER_HOME/.config"
sudo -u "$REAL_USER" mkdir -p "$DOTS_CONF"

echo "--- 8/10 Desplegando configuraciones locales ---"
# Lista de carpetas a intentar copiar
CONFIGS=("hypr" "foot" "fuzzel")

for item in "${CONFIGS[@]}"; do
    TARGET="$DOTS_CONF/$item"
    if [ ! -d "$TARGET" ]; then
        if [ -d "$SCRIPT_DIR/$item" ]; then
            echo "Copiando $item desde $SCRIPT_DIR..."
            cp -r "$SCRIPT_DIR/$item" "$DOTS_CONF/"
        elif [ -d "$SCRIPT_DIR/../$item" ]; then
            echo "Copiando $item desde nivel superior..."
            cp -r "$SCRIPT_DIR/../$item" "$DOTS_CONF/"
        elif [ "$(basename "$SCRIPT_DIR")" == "$item" ]; then
            echo "Desplegando $item desde el directorio actual..."
            mkdir -p "$TARGET"
            cp -r "$SCRIPT_DIR"/* "$TARGET/"
        else
            echo "ADVERTENCIA: No se encontró la carpeta de configuración para $item"
        fi
    fi
done

# Configuración de Eww personalizada de JoseloFlores
if [ ! -d "$DOTS_CONF/eww" ]; then
    echo "Descargando configuración de Eww personalizada..."
    if ! sudo -u "$REAL_USER" git clone https://github.com/JoseloFlores/eww "$DOTS_CONF/eww"; then
        echo "ERROR: No se pudo clonar el repo de Eww."
    fi
fi

# 9. Ajustes finales de rutas y permisos
echo "--- 9/10 Ajustando rutas y permisos ---"
# Corregir rutas hardcodeadas en los archivos desplegados
if [ -d "$DOTS_CONF/hypr" ]; then
    find "$DOTS_CONF/hypr" -type f \( -name "*.sh" -o -name "*.yuck" -o -name "*.conf" \) -exec sed -i "s|/home/jose|$USER_HOME|g" {} +
fi
if [ -d "$DOTS_CONF/eww" ]; then
    find "$DOTS_CONF/eww" -type f \( -name "*.sh" -o -name "*.yuck" -o -name "*.conf" \) -exec sed -i "s|/home/jose|$USER_HOME|g" {} +
    # Corregir la ruta de eww en los scripts para usar el binario global
    find "$DOTS_CONF/hypr" "$DOTS_CONF/eww" -type f \( -name "*.sh" -o -name "*.yuck" \) -exec sed -i "s|$USER_HOME/eww/target/release/eww|eww|g" {} +
fi

# Asegurar que el usuario sea dueño de su home y los scripts sean ejecutables
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} +

# 10. Habilitar servicios
echo "--- 10/10 Habilitando servicios de arranque ---"
systemctl disable sddm lightdm gdm || true
systemctl enable greetd
systemctl set-default graphical.target

echo "-------------------------------------------------------"
echo "¡Instalación completada!"
echo "IMPORTANTE: Reinicia el sistema para iniciar Hyprland."
echo "Si algo falla, revisa el archivo: $(pwd)/$LOG_FILE"
echo "-------------------------------------------------------"
