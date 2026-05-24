#!/bin/bash

# =============================================================================
#  Hyprland Dots Installer - Universal script (Arch, Debian, Fedora)
# =============================================================================

set -e

# Detectar gestor de paquetes
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "No se pudo detectar el sistema operativo."
    exit 1
fi

echo "Detectado: $OS"

# Mapeo de paquetes por distribución
case "$OS" in
    arch)
        PACKAGES="hyprland waybar swaybg wofi foot nautilus playerctl wireplumber brightnessctl grim slurp swappy jq ttf-font-awesome pavucontrol blueman hyprlock hypridle polkit-kde-agent"
        INSTALL_CMD="sudo pacman -S --needed --noconfirm"
        ;;
    debian|ubuntu|pop)
        PACKAGES="hyprland waybar swaybg wofi foot nautilus playerctl wireplumber brightnessctl grim slurp swappy jq fonts-font-awesome pavucontrol blueman hyprlock hypridle hyprpolkitagent libayatana-appindicator3-1"
        INSTALL_CMD="sudo apt update && sudo apt install -y"
        ;;
    fedora)
        PACKAGES="hyprland waybar swaybg wofi foot nautilus playerctl wireplumber-utils brightnessctl grim slurp swappy jq fontawesome-fonts-all pavucontrol blueman hyprlock hypridle"
        INSTALL_CMD="sudo dnf install -y"
        ;;
    *)
        echo "Distribución no soportada automáticamente. Por favor instala los paquetes manualmente."
        exit 1
        ;;
esac

echo "Instalando dependencias..."
$INSTALL_CMD $PACKAGES

# Configuración de directorios
DOTS_DIR="$HOME/.config/hypr"
if [ -d "$DOTS_DIR" ]; then
    echo "Haciendo backup de la configuración actual..."
    mv "$DOTS_DIR" "$DOTS_DIR-$(date +%Y%m%d-%H%M%S).bak"
fi

echo "Instalando configuración..."
mkdir -p "$HOME/.config"
cp -r . "$DOTS_DIR"

# Quitar el script de instalación del destino
rm "$DOTS_DIR/install.sh" || true

# Dar permisos de ejecución a los scripts
chmod +x "$DOTS_DIR"/*.sh

echo "-------------------------------------------------------"
echo "¡Instalación completada!"
echo "Reinicia Hyprland o inicia sesión para ver los cambios."
echo "-------------------------------------------------------"
