#!/bin/bash

# =============================================================================
#  Hyprland & Eww Minimal Installer - Debian 13 (Trixie) - VM OPTIMIZED
# =============================================================================

set -eo pipefail

# Configurar logging
LOG_FILE="install.log"
exec > >(tee -i "$LOG_FILE") 2>&1

echo "--- INICIANDO INSTALACIÓN (Ver log en $LOG_FILE) ---"

# 1. Validaciones Iniciales
if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: Ejecuta con sudo: sudo ./install.sh"
  exit 1
fi

REAL_USER=$SUDO_USER
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Comprobar RAM para Eww
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
echo "Memoria RAM detectada: $TOTAL_RAM MB"
if [ "$TOTAL_RAM" -lt 3500 ]; then
    echo "ADVERTENCIA: Tienes poca RAM. La compilación de Eww podría fallar o congelar la VM."
fi

# 2. Repositorios y Paquetes Base
echo "1/10 Configurando repositorios y actualizando..."
BACKPORTS_FILE="/etc/apt/sources.list.d/trixie-backports.list"
if [ ! -f "$BACKPORTS_FILE" ]; then
    echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" | tee "$BACKPORTS_FILE"
fi
apt update

echo "2/10 Instalando dependencias de sistema y video..."
apt install -y --no-install-recommends \
    firmware-linux-nonfree mesa-va-drivers libgl1-mesa-dri va-driver-all \
    wget curl bc jq git build-essential pkg-config \
    network-manager nm-connection-editor udiskie foot thunar fuzzel \
    playerctl wireplumber brightnessctl grim slurp swappy pavucontrol \
    blueman firefox-esr swaybg zenity zsh vim lxappearance

echo "3/10 Instalando Hyprland y Greetd (Backports)..."
apt install -y -t trixie-backports --no-install-recommends \
    hyprland hyprlock hypridle hyprpolkitagent greetd

# 3. Instalación de tuigreet
if [ ! -f "/usr/bin/tuigreet" ]; then
    echo "4/10 Instalando tuigreet..."
    TUIGREET_VERSION="0.9.1"
    wget -q "https://github.com/apognu/tuigreet/releases/download/$TUIGREET_VERSION/tuigreet-$TUIGREET_VERSION.tar.gz" -O /tmp/tuigreet.tar.gz
    mkdir -p /tmp/tuigreet_ext
    tar -xzf /tmp/tuigreet.tar.gz -C /tmp/tuigreet_ext
    find /tmp/tuigreet_ext -name tuigreet -type f -exec cp {} /usr/bin/ \;
    chmod +x /usr/bin/tuigreet
    rm -rf /tmp/tuigreet.tar.gz /tmp/tuigreet_ext
fi

# 4. Compilación de Eww
echo "5/10 Preparando compilación de Eww..."
apt install -y --no-install-recommends \
    rustc cargo libgtk-3-dev libgtk-layer-shell-dev \
    libpangocairo-1.0-0 libcairo-gobject2 libglib2.0-dev libgdk-pixbuf2.0-dev \
    libpango1.0-dev libdbus-1-dev libssl-dev libcairo2-dev

if [ ! -f "/usr/local/bin/eww" ]; then
    echo "Clonando y compilando Eww (esto toma tiempo)..."
    EWW_BUILD_DIR="/tmp/eww_build"
    rm -rf "$EWW_BUILD_DIR"
    sudo -u "$REAL_USER" git clone https://github.com/elkowar/eww "$EWW_BUILD_DIR"
    cd "$EWW_BUILD_DIR"
    # Usar solo 1 hilo si hay poca RAM para evitar crashes
    JOBS_FLAG=""
    [ "$TOTAL_RAM" -lt 4000 ] && JOBS_FLAG="-j 1"
    
    if ! sudo -u "$REAL_USER" cargo build --release --no-default-features --features wayland $JOBS_FLAG; then
        echo "ERROR: Falló la compilación de Eww. Probablemente falta de RAM."
    else
        cp target/release/eww /usr/local/bin/
    fi
    cd "$SCRIPT_DIR"
fi

# 5. Configuración de Greetd y Hyprland para VM
echo "6/10 Configurando Greetd (VM Friendly)..."
mkdir -p /etc/greetd
# Forzamos renderizado por software y ocultamos cursor de hardware para VMs
# Usamos un script envoltorio para Hyprland con dbus-run-session
cat <<EOF > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "env WLR_NO_HARDWARE_CURSORS=1 WLR_RENDERER_ALLOW_SOFTWARE=1 /usr/bin/tuigreet --time --remember --cmd 'dbus-run-session Hyprland'"
user = "_greetd"
EOF
usermod -aG video,render _greetd || true

# Crear un override para systemd de greetd para asegurar que espera a los servicios de video
mkdir -p /etc/systemd/system/greetd.service.d/
cat <<EOF > /etc/systemd/system/greetd.service.d/override.conf
[Service]
Restart=always
RestartSec=5
EOF
systemctl daemon-reload

# 6. Despliegue de Configuraciones (Dots)
DOTS_CONF="$USER_HOME/.config"
echo "7/10 Desplegando configuraciones en $DOTS_CONF..."
sudo -u "$REAL_USER" mkdir -p "$DOTS_CONF"

CONFIGS=("hypr" "foot" "fuzzel")
for item in "${CONFIGS[@]}"; do
    TARGET="$DOTS_CONF/$item"
    if [ ! -d "$TARGET" ]; then
        # Buscar la carpeta en varios niveles por si acaso
        SRC=""
        [ -d "$SCRIPT_DIR/$item" ] && SRC="$SCRIPT_DIR/$item"
        [ -d "$SCRIPT_DIR/../$item" ] && SRC="$SCRIPT_DIR/../$item"
        [ "$(basename "$SCRIPT_DIR")" == "$item" ] && SRC="$SCRIPT_DIR"

        if [ -n "$SRC" ]; then
            echo "Copiando $item desde $SRC..."
            if [ "$SRC" == "$SCRIPT_DIR" ]; then
                mkdir -p "$TARGET"
                cp -r "$SRC"/* "$TARGET/"
            else
                cp -r "$SRC" "$DOTS_CONF/"
            fi
        else
            echo "ADVERTENCIA: No se encontró la carpeta $item"
        fi
    fi
done

# Eww config personalizada
if [ ! -d "$DOTS_CONF/eww" ]; then
    echo "Clonando configuración de Eww..."
    sudo -u "$REAL_USER" git clone https://github.com/JoseloFlores/eww "$DOTS_CONF/eww" || true
fi

# 7. Permisos y Rutas
echo "8/10 Finalizando permisos y rutas..."
find "$DOTS_CONF" -type f \( -name "*.sh" -o -name "*.yuck" -o -name "*.conf" \) -exec sed -i "s|/home/jose|$USER_HOME|g" {} + 2>/dev/null || true
# Asegurar que use el eww global
find "$DOTS_CONF" -type f \( -name "*.sh" -o -name "*.yuck" \) -exec sed -i "s|$USER_HOME/eww/target/release/eww|eww|g" {} + 2>/dev/null || true

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} +

# 8. Servicios
echo "9/10 Habilitando servicios..."
systemctl disable sddm lightdm gdm getty@tty1.service || true
systemctl mask getty@tty1.service || true # Evitar que la TTY robe el foco a greetd
systemctl enable greetd
systemctl set-default graphical.target

echo "--- 10/10 DIAGNÓSTICO FINAL ---"
systemctl is-enabled greetd
ls -l /usr/bin/tuigreet /usr/bin/Hyprland

echo "-------------------------------------------------------"
echo "¡INSTALACIÓN COMPLETADA!"
echo "REINICIA AHORA: 'sudo reboot'"
echo "Si ves una pantalla negra, pulsa Ctrl+Alt+F2 para ver logs."
echo "-------------------------------------------------------"
