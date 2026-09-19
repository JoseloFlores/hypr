#!/bin/bash
# set-wallpaper.sh — Cambia el wallpaper y sincroniza todo:
#   escritorio (swaybg) + bloqueo (hyprlock) + paleta (pywal/quickshell)
#   + terminal (foot) + launcher (fuzzel) + wlogout
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
# Se evita --saturate: en este wallpaper generaba tonos rojizos (se prefiere neutro).
# haishoku primero; si falla con algún wallpaper, fallback a colorz.
if command -v wal &>/dev/null; then
    if ! wal --backend haishoku -i "$WALL" > /dev/null 2>&1; then
        echo "Aviso: backend haishoku falló, probando colorz" >&2
        wal --backend colorz -i "$WALL" > /dev/null 2>&1 \
            || echo "Aviso: 'wal -i' falló, paleta sin actualizar" >&2
    fi
fi

# 3.5 Terminal foot + launcher fuzzel desde pywal (consistentes con quickshell:
#       quickshell usa color4 como primary — fuzzel lo usa como acento)
if [[ -f "$HOME/.cache/wal/colors.json" ]] && command -v jq &>/dev/null; then
    # --- foot: pywal [colors-dark] -> foot [colors] ---
    FOOT_TEMPLATE="$HOME/.cache/wal/colors-foot-dark.ini"
    FOOT_COLORS="$HOME/.config/foot/colors.ini"
    if [[ -f "$FOOT_TEMPLATE" ]]; then
        mkdir -p "$(dirname "$FOOT_COLORS")"
        {
            echo "# Generado por set-wallpaper.sh desde pywal ($(basename "$SRC")) — no editar a mano"
            sed 's/^\[colors-dark\]/[colors]/; /^alpha=/d' "$FOOT_TEMPLATE"
        } > "$FOOT_COLORS.tmp" && mv "$FOOT_COLORS.tmp" "$FOOT_COLORS"
        echo "Foot sincronizado con pywal -> $FOOT_COLORS"
    fi
    # --- fuzzel: solo [colors], preserva [main]/[border]/[dmenu] y translucidez e6 ---
    PW_BG=$(jq -r '.special.background' "$HOME/.cache/wal/colors.json" | tr -d '#')
    PW_FG=$(jq -r '.special.foreground' "$HOME/.cache/wal/colors.json" | tr -d '#')
    PW_ACC=$(jq -r '.colors.color4' "$HOME/.cache/wal/colors.json" | tr -d '#')
    if [[ -n "$PW_BG" && -n "$PW_FG" && -n "$PW_ACC" ]]; then
        python3 - "$HOME/.config/fuzzel/fuzzel.ini" "$PW_BG" "$PW_FG" "$PW_ACC" <<'PYEOF' \
            && echo "Fuzzel sincronizado con pywal" || echo "Aviso: sync fuzzel falló" >&2
import sys, re, pathlib
cfg_path, BG, FG, ACC = sys.argv[1:5]
desired = {
    "background": BG + "e6",
    "text": FG + "ff",
    "prompt": FG + "ff",
    "placeholder": FG + "80",
    "input": FG + "ff",
    "match": ACC + "ff",
    "selection": ACC + "ff",
    "selection-text": BG + "ff",
    "selection-match": FG + "ff",
    "counter": FG + "80",
    "border": ACC + "ff",
}
p = pathlib.Path(cfg_path)
lines = p.read_text().splitlines()
out, in_colors = [], False
for line in lines:
    s = line.strip()
    if s.startswith("[") and s.endswith("]"):
        in_colors = (s == "[colors]")
        out.append(line)
        continue
    if in_colors:
        m = re.match(r'^\s*([a-z\-]+)\s*=', line)
        if m and m.group(1) in desired:
            out.append(f"{m.group(1)}={desired[m.group(1)]}")
            continue
    out.append(line)
p.write_text("\n".join(out) + "\n")
PYEOF
    fi
    # Los foot nuevos toman los colores solos; fuzzel lee el ini en cada lanzamiento.
    # (No se usa pkill -USR1 foot: en esta build cerraba la terminal.)
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
