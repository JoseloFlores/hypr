#!/bin/bash
# Toggle de grabación de pantalla con wf-recorder (area | full).
# Primera pulsación inicia, segunda detiene la grabación activa.

MODE="${1:-area}"

# Destino de capturas y grabaciones
DIR="$HOME/Pictures/Capturas"
mkdir -p "$DIR"

# Si wf-recorder ya graba → detenerlo con SIGINT (finaliza el mp4 limpiamente)
if pgrep -x wf-recorder > /dev/null 2>&1; then
    for p in $(pgrep -x wf-recorder); do kill -INT "$p"; done
    while pgrep -x wf-recorder > /dev/null 2>&1; do sleep 0.1; done
    notify-send -e -u low -i video-x-generic "Grabador de Pantalla" "Grabación detenida — guardada en $DIR"
    exit 0
fi

OUT="$DIR/Video_$(date +%Y%m%d_%H%M%S).mp4"

if [ "$MODE" = "full" ]; then
    # -o explícito: con 2+ monitores wf-recorder pregunta y falla sin TTY.
    # Foco primero, si no el primer monitor disponible (portable entre equipos).
    OUT_MON=$(hyprctl monitors -j 2>/dev/null | jq -r '((.[] | select(.focused==1) | .name) // .[0].name) // empty' 2>/dev/null)
    [ -z "$OUT_MON" ] && OUT_MON="eDP-1"
    notify-send -e -u low -i video-x-generic "Grabador de Pantalla" "Grabación iniciada ($OUT_MON)"
    exec wf-recorder -o "$OUT_MON" -f "$OUT"
fi

# Área: notifica solo si se seleccionó algo (ESC cancela)
GEOM=$(slurp)
[ -z "$GEOM" ] && exit 1
notify-send -e -u low -i video-x-generic "Grabador de Pantalla" "Grabación iniciada (Área)"
exec wf-recorder -g "$GEOM" -f "$OUT"