#!/bin/bash
# set-wallpaper.sh — Cambia el wallpaper y sincroniza todo:
#   escritorio (swaybg) + bloqueo (hyprlock) + paleta (pywal/quickshell) + wlogout
# Uso:
#   set-wallpaper.sh /ruta/a/imagen.jpg
#   set-wallpaper.sh --random [directorio]   (por defecto ~/Imágenes/wallpapers/wallpaper)
set -euo pipefail

WALL="$HOME/.config/hypr/wallpaper.jpg"
WALLPAPER_DIR="$HOME/Imágenes/wallpapers/wallpaper"
WLOGOUT_CSS="$HOME/.config/wlogout/style.css"
ICON_DIR="$HOME/.local/share/wlogout/icons"

pick_random() {
    local dir="${1:-$WALLPAPER_DIR}"
    find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | shuf -n 1
}

if [[ "${1:-}" == "--random" ]]; then
    SRC="$(pick_random "${2:-}")"
    [[ -n "$SRC" ]] || { echo "No se encontraron imágenes en ${2:-$WALLPAPER_DIR}" >&2; exit 1; }
elif [[ -n "${1:-}" ]]; then
    SRC="$1"
    [[ -f "$SRC" ]] || { echo "No existe: $SRC" >&2; exit 1; }
else
    echo "Uso: $0 <imagen> | $0 --random [directorio]" >&2
    exit 1
fi

# 1. Archivo canónico (lo leen swaybg y hyprlock)
if [[ "$SRC" -ef "$WALL" ]] 2>/dev/null; then
    : # ya es el archivo canónico, nada que copiar
else
    cp "$SRC" "$WALL"
fi

# 2. Escritorio: reiniciar swaybg con la imagen nueva
pkill -x swaybg 2>/dev/null || true
sleep 0.3
nohup swaybg -i "$WALL" -m fill > /dev/null 2>&1 &
disown || true

# 3. Paleta pywal (quickshell la recarga sola vía FileView)
# Nota: backend colorz porque ImageMagick no está instalado
if command -v wal &>/dev/null; then
    wal --backend colorz -i "$WALL" > /dev/null 2>&1 || echo "Aviso: 'wal -i' falló, paleta sin actualizar" >&2
fi

# 4. wlogout al tono de la paleta
if [[ -f "$HOME/.cache/wal/colors.json" ]] && command -v jq &>/dev/null; then
    BG=$(jq -r '.special.background' "$HOME/.cache/wal/colors.json")
    FG=$(jq -r '.special.foreground' "$HOME/.cache/wal/colors.json")
    C1=$(jq -r '.colors.color1' "$HOME/.cache/wal/colors.json")
    C4=$(jq -r '.colors.color4' "$HOME/.cache/wal/colors.json")
    C8=$(jq -r '.colors.color8' "$HOME/.cache/wal/colors.json")
    # rgba helpers
    hex2rgb() { printf "%d, %d, %d" "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"; }
    cat > "$WLOGOUT_CSS" <<EOF
* {
	background-image: none;
	box-shadow: none;
	font-family: "Inter";
}

window {
	background-color: rgba($(hex2rgb "$BG"), 0.85);
}

button {
	border-radius: 20px;
	border-color: rgba($(hex2rgb "$C8"), 0.5);
	text-decoration-color: $FG;
	color: $FG;
	background-color: rgba(18, 26, 34, 0.95);
	border-style: solid;
	border-width: 1px;
	background-repeat: no-repeat;
	background-position: center;
	background-size: 25%;
	margin: 12px;
	padding: 24px;
}

button:focus, button:active, button:hover {
	background-color: rgba($(hex2rgb "$C4"), 0.35);
	border-color: $C4;
	outline-style: none;
}

#lock {
    background-image: image(url("$ICON_DIR/lock.png"));
}

#logout {
    background-image: image(url("$ICON_DIR/logout.png"));
}

#suspend {
    background-image: image(url("$ICON_DIR/suspend.png"));
}

#hibernate {
    background-image: image(url("$ICON_DIR/hibernate.png"));
}

#shutdown {
    background-image: image(url("$ICON_DIR/shutdown.png"));
}

#shutdown:focus, #shutdown:active, #shutdown:hover {
	background-color: rgba($(hex2rgb "$C1"), 0.4);
	border-color: $C1;
}

#reboot {
    background-image: image(url("$ICON_DIR/reboot.png"));
}
EOF
fi

notify-send "Wallpaper" "Actualizado: $(basename "$SRC")" 2>/dev/null || true
echo "Wallpaper actualizado: $SRC"
