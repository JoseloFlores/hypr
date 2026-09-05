#!/bin/bash

# Configuración de temas para Waybar, Foot y Fuzzel
# Fuente de verdad: ~/.config/waybar/themes/<nombre>.css  (y style.css @define-color)

WAYBAR_STYLE="$HOME/.config/waybar/style.css"
THEMES_DIR="$HOME/.config/waybar/themes"
FOOT_COLORS="$HOME/.config/foot/colors.ini"
FUZZEL_CONFIG="$HOME/.config/fuzzel/fuzzel.ini"

# Fallback repo plano si no existe ~/.config/waybar (primera ejecución / install.sh)
if [ ! -d "$THEMES_DIR" ] || [ -z "$(ls -A "$THEMES_DIR" 2>/dev/null)" ]; then
  REPO_THEMES="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/waybar/themes"
  if [ -d "$REPO_THEMES" ]; then
    THEMES_DIR="$REPO_THEMES"
    [ ! -f "$WAYBAR_STYLE" ] && WAYBAR_STYLE="$REPO_THEMES/../style.css"
  fi
fi

# 1. Detectar el tema activo en Waybar
# Busca el tema aplicado en style.css comparando @define-color, o usa ash-dark por defecto
detect_theme() {
  if [ -f "$WAYBAR_STYLE" ]; then
    # Intentar inferir por bg dominante comparando con themes/*.css
    for th in "$THEMES_DIR"/*.css; do
      [ -f "$th" ] || continue
      bg_th=$(grep "@define-color bg " "$th" | awk '{print $3}' | tr -d ';' | head -n1)
      bg_cur=$(grep "@define-color bg " "$WAYBAR_STYLE" | awk '{print $3}' | tr -d ';' | head -n1)
      if [ -n "$bg_th" ] && [ "$bg_th" = "$bg_cur" ]; then
        basename "$th" .css
        return
      fi
    done
  fi
  # Fallback: primer tema disponible o ash-dark
  if [ -f "$THEMES_DIR/ash-dark.css" ]; then echo "ash-dark"; return; fi
  ls -1 "$THEMES_DIR"/*.css 2>/dev/null | head -n1 | xargs -n1 basename 2>/dev/null | sed 's/\.css$//' || echo "ash-dark"
}

THEME_NAME=$(detect_theme)
THEME_PATH="$THEMES_DIR/${THEME_NAME}.css"

if [ ! -f "$THEME_PATH" ]; then
  echo "Error: No se encontró el tema de Waybar en $THEME_PATH" >&2
  echo "Temas disponibles en $THEMES_DIR:" >&2
  ls -1 "$THEMES_DIR"/*.css 2>/dev/null | xargs -n1 basename >&2 || true
  exit 1
fi

echo "Sincronizando sistema con el tema de Waybar: $THEME_NAME"

# Función para extraer color de los archivos .css de Waybar (formato @define-color nombre #hex;)
get_color() {
  local color=$(grep "@define-color $1 " "$THEME_PATH" | awk '{print $3}' | tr -d '#;' | head -n1)
  if [ -z "$color" ]; then
    grep "@define-color fg " "$THEME_PATH" | awk '{print $3}' | tr -d '#;' | head -n1
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
mkdir -p "$(dirname "$FOOT_COLORS")"
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

# 4. Sincronizar Fuzzel (idempotente, crea keys si faltan)
if [ -f "$FUZZEL_CONFIG" ]; then
  for key in background text match selection selection-text selection-match border; do
    if ! grep -q "^${key}=" "$FUZZEL_CONFIG"; then
      echo "${key}=000000ff" >> "$FUZZEL_CONFIG"
    fi
  done
  sed -i "s/^background=.*/background=${BG}ff/" "$FUZZEL_CONFIG"
  sed -i "s/^text=.*/text=${FG}ff/" "$FUZZEL_CONFIG"
  sed -i "s/^match=.*/match=${BLUE}ff/" "$FUZZEL_CONFIG"
  sed -i "s/^selection=.*/selection=${BLUE}ff/" "$FUZZEL_CONFIG"
  sed -i "s/^selection-text=.*/selection-text=${BG}ff/" "$FUZZEL_CONFIG"
  sed -i "s/^selection-match=.*/selection-match=${FG}ff/" "$FUZZEL_CONFIG"
  sed -i "s/^border=.*/border=${BLUE}ff/" "$FUZZEL_CONFIG"
  echo "Fuzzel sincronizado."
fi

# 4b. Sincronizar Waybar
WAYBAR_THEME_SH="$HOME/.config/waybar/scripts/waybar-theme.sh"
if [ ! -x "$WAYBAR_THEME_SH" ]; then
  if [ -x "$(dirname "$0")/waybar/scripts/waybar-theme.sh" ]; then
    WAYBAR_THEME_SH="$(dirname "$0")/waybar/scripts/waybar-theme.sh"
  elif [ -x "$HOME/.config/hypr/waybar/scripts/waybar-theme.sh" ]; then
    WAYBAR_THEME_SH="$HOME/.config/hypr/waybar/scripts/waybar-theme.sh"
  fi
fi
if [ -x "$WAYBAR_THEME_SH" ]; then
  echo "Sincronizando Waybar con tema: $THEME_NAME"
  "$WAYBAR_THEME_SH" "$THEME_NAME" || true
else
  echo "WARN: waybar-theme.sh no encontrado, Waybar ya está sincronizado vía palette"
  pkill -SIGUSR2 waybar 2>/dev/null || true
fi

# 5. Propagar a gsettings si existe (para que nwg-look/lxappearance no rompa Waybar en Wayland)
if command -v gsettings &>/dev/null && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  echo "Tip Wayland: usa 'nwg-look' en vez de lxappearance para temas GTK sin romper Waybar (Wayland native)"
fi

echo "Sincronización completada con éxito (Waybar + Foot + Fuzzel)."
