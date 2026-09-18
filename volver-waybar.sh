#!/bin/bash
# volver-waybar.sh — Vuelve a Waybar tras probar QuickShell
# Uso: ~/.config/hypr/volver-waybar.sh

echo "⏸ Deteniendo QuickShell..."
pkill -x quickshell 2>/dev/null
pkill -x qs 2>/dev/null
sleep 0.5

echo "🔄 Restaurando swaync + Waybar..."
swaync & disown
~/.config/hypr/waybar-launcher.sh & disown
sleep 1

echo "✅ Estado:"
pgrep -a "waybar|swaync|quickshell" || echo "(nada corriendo)"
