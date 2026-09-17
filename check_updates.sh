#!/bin/bash
# check_updates.sh — conteo de updates para Waybar (rápido con caché)
# Primera pintura instantánea desde caché; recuenta en fondo y refresca vía SIGRTMIN+8.
# Waybar: custom/updates con interval 300, signal 8, hide-empty-text true.

CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-updates-count"
LOCK_FILE="/tmp/waybar-updates.lock"
STALE_AFTER=300   # si la caché supera esto, recuenta en fondo
CACHE_MAX_AGE=900 # más allá de esto se considera muy vieja (igual se emite + refresco)

mkdir -p "$(dirname "$CACHE_FILE")" 2>/dev/null || true

emit() {
  local count="$1"
  [[ "$count" =~ ^[0-9]+$ ]] || count=0
  if [ "$count" -gt 0 ]; then
    printf '{"text": "󰚰 %s", "tooltip": "%s actualizaciones pendientes (click para actualizar)", "class": "pending", "alt": "pending"}\n' "$count" "$count"
  else
    printf '{"text": "", "tooltip": "Sistema actualizado", "class": "updated", "alt": "updated"}\n'
  fi
}

count_updates_sync() {
  local count=0
  if command -v apt &>/dev/null; then
    count=$(timeout 20 bash -c 'LC_ALL=C apt list --upgradable 2>/dev/null | grep -c "upgradable"' 2>/dev/null)
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
  elif command -v checkupdates &>/dev/null; then
    count=$(timeout 20 checkupdates 2>/dev/null | wc -l)
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
  else
    count=0
  fi
  echo "$count"
}

refresh_in_background() {
  # Subshell en fondo con flock no bloqueante: solo un recuento a la vez.
  (
    exec 9>"$LOCK_FILE"
    flock -n 9 || exit 0
    count=$(count_updates_sync)
    echo "$count" > "${CACHE_FILE}.tmp" 2>/dev/null && mv -f "${CACHE_FILE}.tmp" "$CACHE_FILE" 2>/dev/null
    pkill -x -SIGRTMIN+8 waybar 2>/dev/null || true
  ) &
}

# --- Camino principal: instantáneo, nunca bloquea la barra ---
age=999999
cached=""
if [ -f "$CACHE_FILE" ]; then
  mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  age=$((now - mtime))
  cached=$(cat "$CACHE_FILE" 2>/dev/null | tr -d ' \n')
  [[ "$cached" =~ ^[0-9]+$ ]] || cached=0
else
  cached=0
fi

emit "$cached"

# Recuenta en fondo si no hay caché o está pasada.
if [ "$age" -gt "$STALE_AFTER" ]; then
  refresh_in_background
fi
