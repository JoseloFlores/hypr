#!/bin/bash

# Configuración de temas para Waybar, Foot y Fuzzel
# Fuente de verdad: ~/.config/waybar/themes/<nombre>.css  (y style.css @import "themes/<tema>.css")

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
# Preferencia: @import "themes/<tema>.css", fallback legacy @define-color bg
detect_theme() {
  if [ -f "$WAYBAR_STYLE" ]; then
    if grep -q '@import.*themes/' "$WAYBAR_STYLE" 2>/dev/null; then
      import_theme=$(grep '@import.*themes/' "$WAYBAR_STYLE" 2>/dev/null | sed -E 's|.*themes/([^"/.]+)\.css.*|\1|' | head -n1)
      if [ -n "$import_theme" ] && [ -f "$THEMES_DIR/${import_theme}.css" ]; then
        echo "$import_theme"
        return
      fi
      # también buscar si algún theme del dir coincide con import aunque path sea relativo distinto
      if [ -n "$import_theme" ]; then
        echo "$import_theme"
        return
      fi
    fi
    # Fallback legacy: inferir por bg dominante comparando con themes/*.css
    for th in "$THEMES_DIR"/*.css; do
      [ -f "$th" ] || continue
      bg_th=$(grep "@define-color bg " "$th" | awk '{print $3}' | tr -d ';' | head -n1)
      bg_cur=$(grep "@define-color bg " "$WAYBAR_STYLE" 2>/dev/null | awk '{print $3}' | tr -d ' ;' | head -n1)
      if [ -n "$bg_th" ] && [ -n "$bg_cur" ] && [ "$bg_th" = "$bg_cur" ]; then
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
# Archivo generado automáticamente por foot_sync.sh — tema: $THEME_NAME
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
echo "Foot sincronizado: $THEME_NAME -> $FOOT_COLORS"

# 3b. Asegurar foot.ini con include
FOOT_MAIN="$HOME/.config/foot/foot.ini"
REPO_FOOT_TEMPLATE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/foot.ini"
[ ! -f "$REPO_FOOT_TEMPLATE" ] && REPO_FOOT_TEMPLATE="$HOME/.config/hypr/foot.ini"
mkdir -p "$(dirname "$FOOT_MAIN")"
if [ ! -f "$FOOT_MAIN" ]; then
  if [ -f "$REPO_FOOT_TEMPLATE" ]; then
    cp -f "$REPO_FOOT_TEMPLATE" "$FOOT_MAIN"
    echo "Foot config creado desde plantilla: $FOOT_MAIN"
  else
    cat > "$FOOT_MAIN" <<FOOT_EOF
include=~/.config/foot/colors.ini
[main]
font=MesloLGM Nerd Font Mono:size=10
FOOT_EOF
  fi
else
  # Asegurar include existe
  if ! grep -q "^include=.*colors.ini" "$FOOT_MAIN"; then
    # Prepend include si falta
    tmp_foot=$(mktemp)
    echo "include=~/.config/foot/colors.ini" > "$tmp_foot"
    echo "" >> "$tmp_foot"
    cat "$FOOT_MAIN" >> "$tmp_foot"
    mv "$tmp_foot" "$FOOT_MAIN"
    echo "Foot config: añadido include colors.ini"
  fi
fi

# 4. Sincronizar Fuzzel — dinámico, translúcido, creación si falta
mkdir -p "$(dirname "$FUZZEL_CONFIG")"
# Colores translúcidos (background e6 ~90%, placeholder/counter semitransparente)
BG_T="${BG}e6"
FG_FF="${FG}ff"
BLUE_FF="${BLUE}ff"
BG_FF="${BG}ff"
BLACK_T="${BLACK}ff"

# Si no existe, crear desde plantilla o base mínima
if [ ! -f "$FUZZEL_CONFIG" ]; then
  REPO_FUZZEL_TEMPLATE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/fuzzel.ini"
  [ ! -f "$REPO_FUZZEL_TEMPLATE" ] && REPO_FUZZEL_TEMPLATE="$HOME/.config/hypr/fuzzel.ini"
  if [ -f "$REPO_FUZZEL_TEMPLATE" ]; then
    cp -f "$REPO_FUZZEL_TEMPLATE" "$FUZZEL_CONFIG"
    echo "Fuzzel config creado desde plantilla: $FUZZEL_CONFIG"
  else
    cat > "$FUZZEL_CONFIG" <<FUZZEL_EOF
[main]
font=MesloLGM Nerd Font Mono:size=11
prompt="> "
width=30
lines=15
horizontal-pad=40
vertical-pad=8
inner-pad=4

[colors]
background=${BG_T}
text=${FG_FF}
prompt=${FG_FF}
placeholder=${FG}80
input=${FG_FF}
match=${BLUE_FF}
selection=${BLUE_FF}
selection-text=${BG_FF}
selection-match=${FG_FF}
counter=${FG}80
border=${BLUE_FF}

[border]
width=1
radius=12
FUZZEL_EOF
  fi
fi

# Actualización robusta por secciones usando python3 (maneja comentarios, headers, translucidez)
python3 - "$FUZZEL_CONFIG" "$BG" "$FG" "$BLUE" "$BLACK" <<'PYEOF'
import sys, re, pathlib
cfg_path, BG, FG, BLUE, BLACK = sys.argv[1:6]
BG_T = BG + "e6"
FG_FF = FG + "ff"
BLUE_FF = BLUE + "ff"
BG_FF = BG + "ff"
# placeholder/counter con alpha 80 (~50%)
PLACEHOLDER = FG + "80"
COUNTER = FG + "80"

desired = {
    "background": BG_T,
    "text": FG_FF,
    "prompt": FG_FF,
    "placeholder": PLACEHOLDER,
    "input": FG_FF,
    "match": BLUE_FF,
    "selection": BLUE_FF,
    "selection-text": BG_FF,
    "selection-match": FG_FF,
    "counter": COUNTER,
    "border": BLUE_FF,
}
border_desired = {"width": "1", "radius": "12"}

p = pathlib.Path(cfg_path)
text = p.read_text()

# Asegurar secciones existen
if "[colors]" not in text:
    text = text.rstrip() + "\n\n[colors]\n"
if "[border]" not in text:
    text = text.rstrip() + "\n\n[border]\nwidth=1\nradius=12\n"

lines = text.splitlines()
out = []
current = None
# track which keys we've updated
seen_colors = set()
seen_border = set()

for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        # al salir de [colors], inyectar faltantes antes de nueva sección
        if current == "colors":
            for k, v in desired.items():
                if k not in seen_colors:
                    out.append(f"{k}={v}")
        if current == "border":
            for k, v in border_desired.items():
                if k not in seen_border:
                    out.append(f"{k}={v}")
        current = stripped[1:-1].strip()
        out.append(line)
        continue

    if current == "colors":
        # match key= value, tolera comentarios previos y espacios
        m = re.match(r'^\s*#?\s*([a-zA-Z0-9\-_]+)\s*=\s*.*$', line)
        if m:
            key = m.group(1)
            if key in desired:
                out.append(f"{key}={desired[key]}")
                seen_colors.add(key)
                continue
            # si es clave de color no deseada pero comentada, descomentar? mantener
            elif key in desired:
                out.append(f"{key}={desired[key]}")
                seen_colors.add(key)
                continue
        # línea no es clave de color deseada, mantener
        out.append(line)
    elif current == "border":
        m = re.match(r'^\s*([a-zA-Z0-9\-_]+)\s*=\s*.*$', line)
        if m:
            key = m.group(1)
            if key in border_desired:
                out.append(f"{key}={border_desired[key]}")
                seen_border.add(key)
                continue
        out.append(line)
    else:
        out.append(line)

# al final, si terminamos en colors/border, inyectar faltantes
if current == "colors":
    for k, v in desired.items():
        if k not in seen_colors:
            out.append(f"{k}={v}")
elif current == "border":
    for k, v in border_desired.items():
        if k not in seen_border:
            out.append(f"{k}={v}")
else:
    # si no terminó en esas secciones pero faltan colores (archivo sin sección al final), ya se manejó arriba
    pass

# Si alguna clave de colors nunca se vio porque sección estaba vacía, asegurar
if not seen_colors.issuperset(desired.keys()):
    # encontrar índice de [colors] y insertar
    try:
        idx = next(i for i, l in enumerate(out) if l.strip() == "[colors]")
        insert_at = idx + 1
        # saltar líneas de sección vacías
        for k, v in desired.items():
            if k not in seen_colors:
                out.insert(insert_at, f"{k}={v}")
                insert_at += 1
    except StopIteration:
        pass

p.write_text("\n".join(out) + "\n")
print("Fuzzel sincronizado (translúcido e6) con tema actual.")
PYEOF
echo "Fuzzel sincronizado: $THEME_NAME -> $FUZZEL_CONFIG (translúcido)"

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
