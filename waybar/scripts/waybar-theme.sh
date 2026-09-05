#!/bin/bash
# waybar-theme.sh — Gestiona temas de Waybar (portable Debian 13 trixie / 14 forky)
# Fuente de verdad: ~/.config/waybar/themes/<nombre>.css  y  waybar/style.css @define-color
# Uso: waybar-theme.sh [nombre]  — si no se pasa, detecta tema actual por @define-color bg
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_WAYBAR_DIR="$(dirname "$SCRIPT_DIR")"   # waybar/
REPO_ROOT="$(dirname "$REPO_WAYBAR_DIR")"    # hypr/ (repo plano)

if [ -n "${SUDO_USER:-}" ]; then REAL_USER="$SUDO_USER"; else REAL_USER="$(whoami)"; fi
USER_HOME="$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6)"
[ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ] && USER_HOME="$HOME"

CONFIG_WAYBAR_STYLE_CANDIDATES=(
  "$USER_HOME/.config/waybar/style.css"
  "$REPO_WAYBAR_DIR/style.css"
  "$HOME/.config/waybar/style.css"
)
WAYBAR_STYLE=""
for p in "${CONFIG_WAYBAR_STYLE_CANDIDATES[@]}"; do
  if [ -f "$p" ]; then WAYBAR_STYLE="$p"; break; fi
done
[ -z "$WAYBAR_STYLE" ] && WAYBAR_STYLE="$REPO_WAYBAR_DIR/style.css"

THEMES_WAYBAR_DIR_CANDIDATES=(
  "$USER_HOME/.config/waybar/themes"
  "$REPO_WAYBAR_DIR/themes"
)
THEMES_WAYBAR_DIR=""
for p in "${THEMES_WAYBAR_DIR_CANDIDATES[@]}"; do
  if [ -d "$p" ]; then THEMES_WAYBAR_DIR="$p"; break; fi
done
[ -z "$THEMES_WAYBAR_DIR" ] && THEMES_WAYBAR_DIR="$REPO_WAYBAR_DIR/themes"

# 1. Determinar nombre de tema
THEME_NAME="${1:-}"
if [ -z "$THEME_NAME" ] && [ -f "$WAYBAR_STYLE" ]; then
  # Detectar por coincidencia de @define-color bg con themes/*.css
  cur_bg=$(grep "@define-color bg " "$WAYBAR_STYLE" 2>/dev/null | awk '{print $3}' | tr -d ' ;' | head -n1)
  if [ -n "$cur_bg" ]; then
    for th in "$THEMES_WAYBAR_DIR"/*.css; do
      [ -f "$th" ] || continue
      th_bg=$(grep "@define-color bg " "$th" 2>/dev/null | awk '{print $3}' | tr -d ' ;' | head -n1)
      if [ "$th_bg" = "$cur_bg" ]; then
        THEME_NAME=$(basename "$th" .css)
        break
      fi
    done
  fi
fi
[ -z "$THEME_NAME" ] && THEME_NAME="ash-dark"

THEME_NAME=$(echo "$THEME_NAME" | sed 's/\.css$//; s/\.scss$//')

THEME_WAYBAR_PATH="$THEMES_WAYBAR_DIR/${THEME_NAME}.css"

if [ ! -f "$THEME_WAYBAR_PATH" ]; then
  echo "Error: tema Waybar no encontrado: $THEME_WAYBAR_PATH (tema: $THEME_NAME)" >&2
  echo "Temas disponibles en $THEMES_WAYBAR_DIR:" >&2
  ls -1 "$THEMES_WAYBAR_DIR"/*.css 2>/dev/null | xargs -n1 basename >&2 || true
  exit 1
fi

echo "Aplicando tema Waybar: $THEME_NAME -> $WAYBAR_STYLE"

# 2. Inyectar paleta en style.css
if [ ! -f "$WAYBAR_STYLE" ]; then
  echo "Creando $WAYBAR_STYLE desde plantilla..."
  mkdir -p "$(dirname "$WAYBAR_STYLE")"
  cp "$THEME_WAYBAR_PATH" "$WAYBAR_STYLE.tmp.head"
  cat "$REPO_WAYBAR_DIR/style.css" 2>/dev/null | sed -e '/@define-color/d' -e '/Waybar theme —/d' > "$WAYBAR_STYLE.tmp.tail" || echo "/* tail */" > "$WAYBAR_STYLE.tmp.tail"
  cat "$WAYBAR_STYLE.tmp.head" "$WAYBAR_STYLE.tmp.tail" > "$WAYBAR_STYLE"
  rm -f "$WAYBAR_STYLE.tmp.head" "$WAYBAR_STYLE.tmp.tail"
else
  TMP_STYLE="$(mktemp)"
  grep -v "@define-color" "$WAYBAR_STYLE" | grep -v "Waybar theme —" > "$TMP_STYLE.body" || true
  cat "$THEME_WAYBAR_PATH" "$TMP_STYLE.body" > "$TMP_STYLE.new"
  mv "$TMP_STYLE.new" "$WAYBAR_STYLE"
  rm -f "$TMP_STYLE.body" "$TMP_STYLE"
fi

# Sincronizar también bajo ~/.config si repo es origen y viceversa (portable)
for dest in "$USER_HOME/.config/waybar/style.css" "$REPO_WAYBAR_DIR/style.css"; do
  if [ "$dest" != "$WAYBAR_STYLE" ] && [ -f "$(dirname "$dest")/config.jsonc" -o -d "$(dirname "$dest")" ]; then
    mkdir -p "$(dirname "$dest")"
    cp -f "$WAYBAR_STYLE" "$dest" 2>/dev/null || true
  fi
done

echo "Tema Waybar aplicado: $THEME_NAME"

# 3. Recargar waybar si corre
if pgrep -x waybar >/dev/null 2>&1; then
  echo "Recargando waybar..."
  pkill -SIGUSR2 waybar 2>/dev/null || killall -SIGUSR2 waybar 2>/dev/null || true
  sleep 0.5
  if ! pgrep -x waybar >/dev/null 2>&1; then
    waybar >/dev/null 2>&1 &
  fi
fi

# 4. Nota para sincronía total con foot/fuzzel
if [ -x "$REPO_ROOT/foot_sync.sh" ] && [ "$THEME_NAME" != "" ]; then
  echo "Tip: ejecuta foot_sync.sh para sincronizar Foot/Fuzzel con el mismo tema"
fi

echo "Waybar tema sincronizado: $THEME_NAME"
