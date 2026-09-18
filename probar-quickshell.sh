#!/bin/bash
# probar-quickshell.sh — Prueba QuickShell sin borrar Waybar
# Waybar queda instalado y configurado, solo se detiene en memoria.
# Uso: ~/.config/hypr/probar-quickshell.sh

echo "⏸ Deteniendo Waybar + swaync (solo en memoria, config intacta)..."
pkill -x waybar 2>/dev/null
pkill -x swaync 2>/dev/null
sleep 0.5

echo "🚀 Lanzando QuickShell (Ctrl+C para salir)..."
export PATH="$HOME/.local/bin:$PATH"
QS_DEBUG=1 quickshell --path "$HOME/quickshell/shell.qml"
