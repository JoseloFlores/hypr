#!/bin/bash

# Rutas de archivos
WAYBAR_STYLE="$HOME/.config/hypr/waybar/style.css"
FOOT_COLORS="$HOME/.config/foot/colors.ini"

# 1. Detectar el tema activo en Waybar
THEME_IMPORT=$(grep "@import" "$WAYBAR_STYLE" | head -n 1 | cut -d'"' -f2)
THEME_PATH="$HOME/.config/hypr/waybar/$THEME_IMPORT"

if [ ! -f "$THEME_PATH" ]; then
    echo "Error: No se encontró el tema en $THEME_PATH"
    exit 1
fi

# Función para extraer el color (formato hexadecimal sin # ni ;)
get_color() {
    local color=$(grep "@define-color $1" "$THEME_PATH" | awk '{print $3}' | tr -d '#;')
    # Si el color está vacío, intentar con un fallback o base05
    if [ -z "$color" ]; then
        grep "@define-color base05" "$THEME_PATH" | awk '{print $3}' | tr -d '#;'
    else
        echo "$color"
    fi
}

# Sincronizar Wofi (Enlace Simbólico al tema activo)
WOFI_THEME="$HOME/.config/wofi/theme.css"
ln -sf "$THEME_PATH" "$WOFI_THEME"
echo "Wofi sincronizado con el tema: $THEME_IMPORT"

# 2. Extraer colores del tema de Waybar
BG=$(get_color "base00")
FG=$(get_color "base05")
BLACK=$(get_color "base01")
RED=$(get_color "accent1")
GREEN=$(get_color "accent2")
YELLOW=$(get_color "accent3")
BLUE=$(get_color "accent4")
MAGENTA=$(get_color "accent5")
CYAN=$(get_color "accent6")
WHITE=$(get_color "base05")

# 3. Generar el archivo colors.ini para Foot
cat <<EOF > "$FOOT_COLORS"
# Archivo generado automáticamente por foot_sync.sh
[colors]
background=$BG
foreground=$FG
regular0=$BLACK
regular1=$RED
regular2=$GREEN
regular3=$YELLOW
regular4=$BLUE
regular5=$MAGENTA
regular6=$CYAN
regular7=$WHITE
# Colores brillantes (usamos los mismos o podrías ajustarlos)
bright0=$BLACK
bright1=$RED
bright2=$GREEN
bright3=$YELLOW
bright4=$BLUE
bright5=$MAGENTA
bright6=$CYAN
bright7=$WHITE
EOF

echo "Colores sincronizados con el tema: $THEME_IMPORT"
