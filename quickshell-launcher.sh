#!/bin/bash
# quickshell-launcher.sh — Arranque de Quickshell para Hyprland.
# Espejo de waybar-launcher.sh: Waybar queda instalada e intacta (~/.config/waybar/),
# solo dormida (sin exec-once y con waybar.service disabled).
# Uso en hyprland.conf: exec-once = ~/.config/hypr/quickshell-launcher.sh &
export PATH="$HOME/.local/bin:$PATH"
exec quickshell --path "$HOME/quickshell/shell.qml" "$@"
