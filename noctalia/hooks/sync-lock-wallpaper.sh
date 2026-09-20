#!/usr/bin/env bash
# Hook wallpaper_changed de Noctalia: mantiene ~/.config/hypr/wallpaper.jpg
# sincronizado (es la imagen que usa hyprlock como fondo).
# Noctalia expone NOCTALIA_WALLPAPER_PATH (vacío si es color sólido).
set -euo pipefail

LOCK_WALL="$HOME/.config/hypr/wallpaper.jpg"
SRC="${NOCTALIA_WALLPAPER_PATH:-}"

[ -n "$SRC" ] || exit 0
[ -f "$SRC" ] || exit 0
if [ "$SRC" -ef "$LOCK_WALL" ] 2>/dev/null; then
    exit 0
fi
cp -f "$SRC" "$LOCK_WALL"
