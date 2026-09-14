#!/bin/bash
# auto_timezone.sh — Detecta la zona horaria por IP y actualiza el sistema si cambió.
# Sin zonas hardcodeadas: la zona siempre sale de la geolocalización de la IP.
# Fuentes: ipwho.is (https) con fallback a ip-api.com (http).

detect_tz() {
  local tz
  tz="$(curl -s --max-time 8 "https://ipwho.is/" | jq -r '.timezone.id // empty' 2>/dev/null)"
  if [ -n "$tz" ]; then
    printf '%s' "$tz"
    return 0
  fi
  tz="$(curl -s --max-time 8 "http://ip-api.com/json/" | jq -r '.timezone // empty' 2>/dev/null)"
  if [ -n "$tz" ]; then
    printf '%s' "$tz"
    return 0
  fi
  return 1
}

tz="$(detect_tz)" || { echo "auto_timezone: sin zona detectada (sin red)"; exit 0; }
current="$(readlink -f /etc/localtime 2>/dev/null | sed 's|^.*/zoneinfo/||')"
[ -n "$current" ] || { echo "auto_timezone: localtime no legible"; exit 0; }

if [ "$current" = "$tz" ]; then
  echo "auto_timezone: zona actual ($current) coincide; sin cambios"
  exit 0
fi

echo "auto_timezone: $current -> $tz"
if timedatectl set-timezone "$tz" 2>/dev/null; then
  notify-send "Zona horaria" "Actualizada a $tz - recargando waybar..." -i clock 2>/dev/null || true
  pkill -x waybar 2>/dev/null || true
  sleep 0.5
  setsid nohup ~/.config/hypr/waybar-launcher.sh >/dev/null 2>&1 < /dev/null &
else
  echo "auto_timezone: fallo al setear zona (¿requiere autorización?)"
  notify-send "Zona horaria" "Detecté $tz pero no pude aplicar el cambio" 2>/dev/null || true
fi