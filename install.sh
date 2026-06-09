#!/bin/bash

# =============================================================================
#  Hyprland & Eww Minimal Installer - Debian 13 (Trixie)
# =============================================================================

set -e

# Comprobación de root
if [ "$EUID" -ne 0 ]; then 
  echo "Por favor, ejecuta este script con sudo."
  exit 1
fi

if [ -z "$SUDO_USER" ]; then
  echo "Por favor, ejecuta el script usando 'sudo ./install.sh'."
  exit 1
fi

REAL_USER=$SUDO_USER
USER_HOME=$(eval echo ~$REAL_USER)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

echo "Iniciando instalación mínima para Debian 13 (Trixie)..."

# 1. Configuración de Repositorios (Asegurar Backports para Hyprland)
echo "Configurando repositorios..."
BACKPORTS_FILE="/etc/apt/sources.list.d/trixie-backports.list"
if [ ! -f "$BACKPORTS_FILE" ]; then
    echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" | tee "$BACKPORTS_FILE"
fi
apt update

# 2. Drivers y Firmware (Esencial y genérico para compatibilidad)
echo "Instalando drivers de video y firmware..."
apt install -y --no-install-recommends \
    firmware-linux-nonfree \
    intel-media-va-driver mesa-va-drivers \
    libgl1-mesa-dri xserver-xorg-video-all

# 3. Herramientas Base del Sistema y Dependencias de Scripts
echo "Instalando utilidades base..."
apt install -y --no-install-recommends \
    wget curl bc jq git build-essential pkg-config \
    network-manager nm-connection-editor \
    udiskie foot thunar fuzzel playerctl wireplumber brightnessctl \
    grim slurp swappy pavucontrol blueman firefox-esr \
    swaybg zenity zsh vim lxappearance

# 4. Hyprland y Ecosistema (Desde Backports cuando sea posible)
echo "Instalando Hyprland, Greetd y Hypr-herramientas..."
apt install -y -t trixie-backports --no-install-recommends \
    hyprland hyprlock hypridle hyprpolkitagent

apt install -y --no-install-recommends greetd

# 5. Instalación de tuigreet (Manual desde GitHub ya que no está en repos de Debian)
if [ ! -f "/usr/bin/tuigreet" ]; then
    echo "Descargando tuigreet desde GitHub..."
    TUIGREET_VERSION="0.9.1"
    wget https://github.com/apognu/tuigreet/releases/download/$TUIGREET_VERSION/tuigreet-$TUIGREET_VERSION.tar.gz -O /tmp/tuigreet.tar.gz
    tar -xzf /tmp/tuigreet.tar.gz -C /tmp
    # Intentar mover el binario buscando su ubicación real tras la extracción
    find /tmp -name tuigreet -type f -exec mv {} /usr/bin/ \;
    chmod +x /usr/bin/tuigreet
    rm -rf /tmp/tuigreet.tar.gz /tmp/tuigreet-$TUIGREET_VERSION
fi

# 6. Compilación de Eww (Desde código fuente)
echo "Instalando dependencias de compilación para Eww..."
apt install -y --no-install-recommends \
    rustc cargo libgtk-3-dev libgtk-layer-shell-dev \
    libpangocairo-1.0-0 libcairo-gobject2 libglib2.0-dev libgdk-pixbuf2.0-dev

if [ ! -f "/usr/local/bin/eww" ]; then
    echo "Clonando y compilando Eww..."
    EWW_BUILD_DIR="/tmp/eww_build"
    rm -rf "$EWW_BUILD_DIR"
    sudo -u "$REAL_USER" git clone https://github.com/elkowar/eww "$EWW_BUILD_DIR"
    cd "$EWW_BUILD_DIR"
    # Compilamos con soporte para Wayland usando los paquetes de Debian
    sudo -u "$REAL_USER" cargo build --release --no-default-features --features wayland
    cp target/release/eww /usr/local/bin/
    cd "$SCRIPT_DIR"
    rm -rf "$EWW_BUILD_DIR"
fi

# 7. Configuración de Greetd (Login ligero)
echo "Configurando Greetd con tuigreet..."
mkdir -p /etc/greetd
cat <<EOF > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet --time --remember --cmd /usr/bin/Hyprland"
user = "_greetd"
EOF
# Asegurar que el usuario _greetd pueda acceder al hardware gráfico
usermod -aG video _greetd || true
usermod -aG render _greetd || true

# 8. Despliegue de Configuraciones (Dots)
DOTS_CONF="$USER_HOME/.config"
mkdir -p "$DOTS_CONF"

echo "Desplegando configuraciones locales..."
# Lista de carpetas a desplegar
CONFIGS=("hypr" "foot" "fuzzel")

for item in "${CONFIGS[@]}"; do
    # 1. Buscar en el mismo directorio que el script
    if [ -d "$SCRIPT_DIR/$item" ]; then
        cp -r "$SCRIPT_DIR/$item" "$DOTS_CONF/"
    # 2. Si el script está DENTRO de la carpeta hypr, buscar hermanos
    elif [ -d "$SCRIPT_DIR/../$item" ]; then
        cp -r "$SCRIPT_DIR/../$item" "$DOTS_CONF/"
    # 3. Caso especial: si el script es parte de la carpeta hypr y queremos desplegar hypr
    elif [ "$(basename "$SCRIPT_DIR")" == "$item" ]; then
        mkdir -p "$DOTS_CONF/$item"
        cp -r "$SCRIPT_DIR"/* "$DOTS_CONF/$item/"
    fi
done

# Clonar la barra personalizada de JoseloFlores si no existe
echo "Descargando configuración de Eww personalizada..."
if [ ! -d "$DOTS_CONF/eww" ]; then
    sudo -u "$REAL_USER" git clone https://github.com/JoseloFlores/eww "$DOTS_CONF/eww"
fi

# 9. Ajustes finales de rutas y permisos
echo "Ajustando rutas y permisos..."
# Reemplazar la ruta hardcodeada /home/jose por la del usuario actual
find "$DOTS_CONF/hypr" "$DOTS_CONF/eww" -type f \( -name "*.sh" -o -name "*.yuck" -o -name "*.conf" \) -exec sed -i "s|/home/jose|$USER_HOME|g" {} +

# Corregir la ruta de eww en los scripts para usar el binario global /usr/local/bin/eww
find "$DOTS_CONF/hypr" "$DOTS_CONF/eww" -type f \( -name "*.sh" -o -name "*.yuck" \) -exec sed -i "s|$USER_HOME/eww/target/release/eww|eww|g" {} +

chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} +

# 10. Habilitar servicios y asegurar arranque en modo gráfico
echo "Habilitando servicios de arranque..."
systemctl disable sddm lightdm gdm || true
systemctl enable greetd
systemctl set-default graphical.target

echo "-------------------------------------------------------"
echo "¡Instalación minimalista completada!"
echo "Sistema: Debian 13 (Trixie) con Hyprland + Eww + Greetd"
echo "Reinicia para iniciar sesión con Greetd."
echo "-------------------------------------------------------"
