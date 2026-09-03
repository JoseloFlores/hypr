#!/bin/bash

# Opciones del menú
options="Bloquear Pantalla\nSuspender\nApagar\nReiniciar\nCerrar Sesion\nCancelar"

# Menú visual con Fuzzel
selected=$(echo -e "$options" | fuzzel --dmenu --prompt "Acciones: " --width 20 --lines 6)

# Acciones directas del sistema
case "$selected" in
    "Bloquear Pantalla")
        hyprlock & sleep 2 && hyprctl dispatch dpms off
        ;;
    "Suspender")
        loginctl lock-session && sleep 1 && hyprctl dispatch dpms off && systemctl suspend
        ;;
    "Apagar")
        systemctl poweroff
        ;;
    "Reiniciar")
        systemctl reboot
        ;;
    "Cerrar Sesion")
        hyprctl dispatch exit
        ;;
    "Cancelar")
        exit 0
        ;;
esac

