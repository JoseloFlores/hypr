#!/bin/bash
# Dentro de power_menu.sh
options="Bloquear Pantalla\nSuspender\nApagar\nReiniciar\nCerrar Sesión\nCancelar"

selected=$(echo -e "$options" | wofi -dmenu --style ~/.config/wofi/style3.css -p "Acciones" --width 400 --height 250)

case "$selected" in
    "Bloquear Pantalla")
	hyprlock & sleep 0.1 && hyprctl dispatch dpms off
	;;
    "Suspender")
        ~/.config/hypr/confirm_power.sh "¿Suspender el sistema?" "loginctl lock-session && sleep 1 && hyprctl dispatch dpms off && systemctl suspend"
        ;;
    "Apagar")
        ~/.config/hypr/confirm_power.sh "¿Apagar el sistema?" "systemctl poweroff"
        ;;
    "Reiniciar")
        ~/.config/hypr/confirm_power.sh "¿Reiniciar el sistema?" "systemctl reboot"
        ;;
    "Cerrar Sesión")
        ~/.config/hypr/confirm_power.sh "¿Cerrar sesión?" "hyprctl dispatch exit"
        ;;
    "Cancelar")
        exit 0
        ;;
esac
