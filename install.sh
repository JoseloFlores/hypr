#!/bin/bash

# =============================================================================
#  Hyprland Dots Installer - Debian 13 (Trixie) Edition
# =============================================================================

set -e

# Comprobación de root
if [ "$EUID" -ne 0 ]; then 
  echo "Por favor, ejecuta este script con sudo."
  exit
fi

# Obtener el usuario real y su home
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo ~$REAL_USER)

echo "Iniciando instalación para Debian 13 (Trixie) para el usuario $REAL_USER..."

# 1. Habilitar Backports y Repositorios de Terceros (Chrome & Spotify)
echo "Configurando repositorios..."

# Backports
BACKPORTS_FILE="/etc/apt/sources.list.d/trixie-backports.list"
if [ ! -f "$BACKPORTS_FILE" ]; then
    echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" | sudo tee "$BACKPORTS_FILE"
fi

# Google Chrome
if [ ! -f "/etc/apt/sources.list.d/google-chrome.list" ]; then
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor | sudo tee /usr/share/keyrings/google-chrome.gpg > /dev/null
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
fi

# Spotify
if [ ! -f "/etc/apt/sources.list.d/spotify.list" ]; then
    curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/spotify.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/spotify.gpg] http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
fi

apt update

# 2. Instalar Drivers y dependencias de compilación
echo "Instalando drivers, herramientas de compilación y dependencias..."
apt install -y \
    firmware-linux-nonfree intel-media-va-driver mesa-va-drivers \
    build-essential git pkg-config libgtk-3-dev libgtk-layer-shell-dev \
    libpulse-dev libdbus-1-dev libcommon-sense-perl libpango1.0-dev \
    libcairo2-dev libgdk-pixbuf2.0-dev libglib2.0-dev libatk1.0-dev \
    wget curl bc jq 

# Instalar Rust desde backports para Eww
apt install -t trixie-backports -y rustc cargo

# 3. Instalar Hyprland, Apps y Ecosistema
echo "Instalando programas..."
apt install -t trixie-backports -y \
    hyprland \
    sddm \
    hyprpolkitagent \
    udiskie \
    foot \
    thunar \
    fuzzel \
    playerctl \
    wireplumber \
    brightnessctl \
    grim \
    slurp \
    swappy \
    pavucontrol \
    blueman \
    hyprlock \
    hypridle \
    libayatana-appindicator3-1 \
    swaybg \
    zenity \
    gnome-control-center \
    gnome-calendar \
    network-manager \
    google-chrome-stable \
    spotify-client \
    zsh \
    vim

# 4. Compilar e instalar Eww
echo "Compilando Eww..."
TEMP_EWW="/tmp/eww_build"
rm -rf "$TEMP_EWW"
git clone https://github.com/elkowar/eww "$TEMP_EWW"
cd "$TEMP_EWW"
cargo build --release --no-default-features --features=wayland
install -m 755 target/release/eww /usr/local/bin/eww
cd -
rm -rf "$TEMP_EWW"

# 5. Configuración de archivos (Dots)
DOTS_CONF="$USER_HOME/.config"
mkdir -p "$DOTS_CONF"

echo "Desplegando configuraciones..."

# A) Hyprland, Foot, Fuzzel (desde el directorio actual del script)
# Asumimos que el script se ejecuta desde la raíz de los dots del usuario
cp -r hypr foot fuzzel "$DOTS_CONF/"

# B) Eww (desde el repo de personalización del usuario)
echo "Descargando configuración de Eww personalizada..."
rm -rf "$DOTS_CONF/eww"
git clone https://github.com/JoseloFlores/eww "$DOTS_CONF/eww"

# 6. Generalización de rutas
echo "Ajustando rutas para el usuario actual..."

# Reemplazar /home/jose por el home del usuario actual en todos los configs
find "$DOTS_CONF/hypr" "$DOTS_CONF/eww" -type f \( -name "*.sh" -o -name "*.yuck" -o -name "*.conf" \) -exec sed -i "s|/home/jose|$USER_HOME|g" {} +

# Asegurar que los scripts usen el binario de eww en /usr/local/bin
find "$DOTS_CONF/hypr" "$DOTS_CONF/eww" -type f \( -name "*.sh" -o -name "*.yuck" \) -exec sed -i "s|$USER_HOME/eww/target/release/eww|eww|g" {} +

# Ajustar permisos y propiedad
chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} +

# 7. Habilitar servicios y pre-configurar sesión
echo "Configurando SDDM para iniciar Hyprland por defecto..."
systemctl enable sddm

# Pre-seleccionar Hyprland para el usuario para evitar que tenga que elegirlo manualmente
mkdir -p /var/lib/sddm
cat <<EOF > /var/lib/sddm/state.conf
[Last]
Session=/usr/share/wayland-sessions/hyprland.desktop
User=$REAL_USER
EOF

echo "-------------------------------------------------------"
echo "¡Instalación completada con éxito!"
echo "Binario 'eww' instalado en /usr/local/bin"
echo "Configuraciones desplegadas en $DOTS_CONF"
echo "Reinicia el sistema para iniciar sesión en Hyprland."
echo "-------------------------------------------------------"
