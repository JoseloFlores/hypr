#!/bin/bash

# Argumentos: $1 = Mensaje para el usuario, $2 = Comando a ejecutar

# Añadir rutas comunes al PATH para asegurar que comandos como systemctl o shutdown funcionen
export PATH=$PATH:/usr/bin:/usr/sbin:/bin:/sbin

# Detectar y exportar display para que zenity funcione desde Waybar (Wayland)
if [ -n "$WAYLAND_DISPLAY" ]; then
    export WAYLAND_DISPLAY="$WAYLAND_DISPLAY"
elif [ -n "$DISPLAY" ]; then
    export DISPLAY="$DISPLAY"
else
    # Fallback: intentar detectar automáticamente
    export WAYLAND_DISPLAY="wayland-1"
    export DISPLAY=":0"
fi
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export GTK_A11Y=none

# Usamos zenity para un diálogo fiable
if zenity --question --text="$1" --title="Confirmar" --width=300; then
    echo "Ejecutando: $2" >> /tmp/power_menu.log
    eval "$2" >> /tmp/power_menu.log 2>&1
fi
