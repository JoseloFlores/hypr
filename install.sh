#!/bin/bash

# =============================================================================
#  Hyprland Dots Installer - Debian 13 (Trixie) Edition
# =============================================================================

set -e

# Comprobación de root
if [ "$EUID" -ne 0 ]; then 
  echo "Por favor, ejecuta este script como root o con sudo."
  exit
fi

echo "Iniciando instalación para Debian 13 (Trixie)..."

# 1. Habilitar Backports
BACKPORTS_FILE="/etc/apt/sources.list.d/trixie-backports.list"
if [ ! -f "$BACKPORTS_FILE" ]; then
    echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" | sudo tee "$BACKPORTS_FILE"
    apt update
fi

# 2. Instalar Drivers Intel y dependencias base
echo "Instalando drivers de video y utilidades..."
apt install -y firmware-linux-nonfree intel-media-va-driver mesa-va-drivers

# 3. Instalar Hyprland y ecosistema
echo "Instalando Hyprland, SDDM, y herramientas..."
# Instalamos hyprland explícitamente desde backports
apt install -t trixie-backports -y \
    hyprland \
    sddm \
    hyprpolkitagent \
    udiskie \
    waybar \
    foot \
    thunar \
    fuzzel \
    playerctl \
    wireplumber \
    brightnessctl \
    grim \
    slurp \
    swappy \
    jq \
    fonts-font-awesome \
    pavucontrol \
    blueman \
    hyprlock \
    hypridle \
    libayatana-appindicator3-1 \
    git \
    zsh \
    vim \


# 4. Habilitar servicios
echo "Habilitando SDDM..."
systemctl enable sddm

# 5. Configuración de directorios (usando el usuario real que ejecutó el script con sudo)
USER_HOME=$(eval echo ~$SUDO_USER)
DOTS_DIR="$USER_HOME/.config/hypr"

echo "Instalando configuración en $DOTS_DIR..."
mkdir -p "$USER_HOME/.config"
# Asumimos que este script está en la raíz de los dots
cp -r . "$DOTS_DIR"

# Ajustar permisos
chown -R "$SUDO_USER":"$SUDO_USER" "$DOTS_DIR"
chmod +x "$DOTS_DIR"/*.sh

echo "-------------------------------------------------------"
echo "¡Instalación completada con éxito!"
echo "Reinicia el sistema para iniciar sesión en Hyprland."
echo "-------------------------------------------------------"
