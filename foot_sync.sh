#!/bin/bash

# Configuración de temas para Eww, Foot y Fuzzel
# Fuente de verdad: ~/.config/eww/eww.scss

EWW_SCSS="$HOME/.config/eww/eww.scss"
THEMES_DIR="$HOME/.config/eww/themes"
FOOT_COLORS="$HOME/.config/foot/colors.ini"
FUZZEL_CONFIG="$HOME/.config/fuzzel/fuzzel.ini"

# 1. Detectar el tema activo en Eww
# Busca la línea @import "themes/nombre";
THEME_NAME=$(grep "@import \"themes/" "$EWW_SCSS" | cut -d'"' -f2 | cut -d'/' -f2)
THEME_PATH="$THEMES_DIR/${THEME_NAME}.scss"

if [ ! -f "$THEME_PATH" ]; then
    echo "Error: No se encontró el tema de Eww en $THEME_PATH"
    exit 1
fi

echo "Sincronizando sistema con el tema de Eww: $THEME_NAME"

# Función para extraer color de los archivos .scss de Eww (formato $variable: #hex;)
get_color() {
    local color=$(grep "^\$$1:" "$THEME_PATH" | awk '{print $2}' | tr -d '#;')
    if [ -z "$color" ]; then
        # Fallback si no existe la variable específica
        grep "^\$fg:" "$THEME_PATH" | awk '{print $2}' | tr -d '#;'
    else
        echo "$color"
    fi
}

# 2. Extraer colores
BG=$(get_color "bg")
FG=$(get_color "fg")
BLUE=$(get_color "blue")
CYAN=$(get_color "cyan")
GREEN=$(get_color "green")
PURPLE=$(get_color "purple")
RED=$(get_color "red")
YELLOW=$(get_color "yellow")
BLACK=$(get_color "bg-alt")

# 3. Generar colores para Foot
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
regular5=$PURPLE
regular6=$CYAN
regular7=$FG
bright0=$BLACK
bright1=$RED
bright2=$GREEN
bright3=$YELLOW
bright4=$BLUE
bright5=$PURPLE
bright6=$CYAN
bright7=$FG
EOF

# 4. Sincronizar Fuzzel
if [ -f "$FUZZEL_CONFIG" ]; then
    sed -i "s/^background=.*/background=${BG}ff/" "$FUZZEL_CONFIG"
    sed -i "s/^text=.*/text=${FG}ff/" "$FUZZEL_CONFIG"
    sed -i "s/^match=.*/match=${BLUE}ff/" "$FUZZEL_CONFIG"
    sed -i "s/^selection=.*/selection=${BLUE}ff/" "$FUZZEL_CONFIG"
    sed -i "s/^selection-text=.*/selection-text=${BG}ff/" "$FUZZEL_CONFIG"
    sed -i "s/^selection-match=.*/selection-match=${FG}ff/" "$FUZZEL_CONFIG"
    sed -i "s/^border=.*/border=${BLUE}ff/" "$FUZZEL_CONFIG"
    echo "Fuzzel sincronizado."
fi

echo "Sincronización completada con éxito."
