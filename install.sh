#!/bin/bash

# =============================================================================
#  Hyprland & Eww Installer - Debian 13 (Stable) Backports Edition
# =============================================================================

set -e

# Comprobación de root y de ejecución mediante sudo
if [ "$EUID" -ne 0 ]; then 
  echo "Por favor, ejecuta este script con sudo."
  exit 1
fi

if [ -z "$SUDO_USER" ]; then
  echo "Por favor, ejecuta el script usando 'sudo ./install.sh' desde tu usuario habitual."
  exit 1
fi

REAL_USER=$SUDO_USER
USER_HOME=$(eval echo ~$REAL_USER)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

echo "Iniciando instalación limpia para Debian 13 (Stable) con entorno GTK..."

# 1. Asegurar repositorio de Backports
echo "Configurando repositorios..."
BACKPORTS_FILE="/etc/apt/sources.list.d/trixie-backports.list"
if [ ! -f "$BACKPORTS_FILE" ]; then
    echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" | tee "$BACKPORTS_FILE"
fi

apt update

# 2. Instalar Drivers y Herramientas Base del Sistema
echo "Instalando drivers de video y utilidades del sistema..."
apt install -y \
    firmware-linux-nonfree intel-media-va-driver mesa-va-drivers \
    wget curl bc jq network-manager nm-connection-editor sddm \
    udiskie foot thunar fuzzel playerctl wireplumber brightnessctl \
    grim slurp swappy pavucontrol blueman libayatana-appindicator3-1 \
    swaybg zenity zsh vim

# 3. Componentes específicos para la gestión de entorno GTK y Credenciales
echo "Instalando herramientas de personalización GTK..."
apt install -y \
    lxappearance \
    gsettings-desktop-schemas \
    gnome-keyring \
    gnome-themes-extra

# 4. Instalar Hyprland, Eww y Ecosistema desde Backports
echo "Instalando Hyprland y Eww desde backports..."
apt install -t trixie-backports -y \
    hyprland \
    eww \
    hyprlock \
    hypridle \
    polkit-kde-agent-1

# 5. Configuración de archivos (Dots)
DOTS_CONF="$USER_HOME/.config"
mkdir -p "$DOTS_CONF"

echo "Desplegando configuraciones..."

# A) Copiar entornos locales del script
if [ -d "$SCRIPT_DIR/hypr" ]; then cp -r "$SCRIPT_DIR/hypr" "$DOTS_CONF/"; fi
if [ -d "$SCRIPT_DIR/foot" ]; then cp -r "$SCRIPT_DIR/foot" "$DOTS_CONF/"; fi
if [ -d "$SCRIPT_DIR/fuzzel" ]; then cp -r "$SCRIPT_DIR/fuzzel" "$DOTS_CONF/"; fi

# B) Clonar configuración personalizada de Eww si no existe localmente
echo "Descargando configuración de Eww personalizada..."
rm -rf "$DOTS_CONF/eww"
git clone https://github.com/JoseloFlores/eww "$DOTS_CONF/eww"

# 6. Generalización de rutas y limpieza de rutas de compilación pasadas
echo "Ajustando rutas para el usuario actual..."
find "$DOTS_CONF/hypr" "$DOTS_CONF/eww" -type f \( -name "*.sh" -o -name "*.yuck" -o -name "*.conf" \) -exec sed -i "s|/home/jose|$USER_HOME|g" {} +

# Reemplazar cualquier llamada directa al binario compilado antiguo por el comando global 'eww'
find "$DOTS_CONF/hypr" "$DOTS_CONF/eww" -type f \( -name "*.sh" -o -name "*.yuck" \) -exec sed -i "s|$USER_HOME/eww/target/release/eww|eww|g" {} +

# Ajustar permisos estrictamente a las carpetas creadas
chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF/hypr" "$DOTS_CONF/foot" "$DOTS_CONF/fuzzel" "$DOTS_CONF/eww"
find "$DOTS_CONF/hypr" "$DOTS_CONF/eww" "$DOTS_CONF/foot" "$DOTS_CONF/fuzzel" -name "*.sh" -exec chmod +x {} +

# 7. Habilitar servicios y pre-configurar sesión
echo "Configurando SDDM para iniciar Hyprland por defecto..."
systemctl enable sddm

mkdir -p /var/lib/sddm
cat <<EOF > /var/lib/sddm/state.conf
[Last]
Session=/usr/share/wayland-sessions/hyprland.desktop
User=$REAL_USER
EOF

echo "-------------------------------------------------------"
echo "¡Instalación nativa completada con éxito!"
echo "Hyprland y Eww instalados mediante paquetes oficiales."
echo "Reinicia el sistema para iniciar tu sesión."
echo "-------------------------------------------------------"
