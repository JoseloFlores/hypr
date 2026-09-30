#!/bin/bash
# check-updates.sh — cuenta actualizaciones .deb y flatpak, sin sudo interactivo.
# Uso: check-updates.sh [--no-flatpak] [interval_minutes]
# Imprime una sola linea: "DEB FLAT TOTAL"
set -uo pipefail

NO_FLATPAK=0
for arg in "$@"; do
    [ "$arg" = "--no-flatpak" ] && NO_FLATPAK=1
done

# Gancho de prueba: si existe ~/.cache/noctalia/updates-debug con "DEB FLAT",
# se usa tal cual (para verificar el widget sin instalar nada).
DBG_FILE="$HOME/.cache/noctalia/updates-debug"
if [ -f "$DBG_FILE" ]; then
    read -r D F _ < "$DBG_FILE" || true
    [[ "$D" =~ ^[0-9]+$ ]] || D=0
    [[ "$F" =~ ^[0-9]+$ ]] || F=0
    echo "$D $F $((D + F))"
    exit 0
fi

count_deb() {
    apt-get -s -o Debug::NoLocking=1 upgrade 2>/dev/null | grep -c '^Inst' || true
}

DEB=$(count_deb)

# Best-effort: refrescar listas solo si hay sudo sin contraseña (nunca pide clave).
# Si el usuario quiere chequeos siempre frescos:
#   echo "$USER ALL=(root) NOPASSWD: /usr/bin/apt-get update" | sudo tee /etc/sudoers.d/noctalia-updates
if sudo -n true 2>/dev/null; then
    if sudo -n apt-get update -qq 2>/dev/null; then
        DEB=$(count_deb)
    fi
fi

FLAT=0
if [ "$NO_FLATPAK" = "0" ] && command -v flatpak >/dev/null 2>&1; then
    FLAT=$(timeout 60 flatpak remote-ls --updates --columns=application 2>/dev/null | grep -c . || true)
fi

# Normaliza a enteros por si algo raro llega vacio.
DEB=${DEB:-0}; FLAT=${FLAT:-0}
[[ "$DEB" =~ ^[0-9]+$ ]] || DEB=0
[[ "$FLAT" =~ ^[0-9]+$ ]] || FLAT=0

echo "$DEB $FLAT $((DEB + FLAT))"
