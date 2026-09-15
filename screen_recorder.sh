#!/bin/bash
# Toggle de grabación de pantalla con wf-recorder (area | full).
# Primera pulsación inicia, segunda detiene la grabación activa.

MODE="${1:-area}"

# Directorio portable: XDG_PICTURES_DIR o ~/Pictures, con fallback a ~/Imágenes
DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Capturas"
[ -d "$HOME/Imágenes" ] && [ ! -d "$DIR" ] && DIR="$HOME/Imágenes/Capturas"
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
    notify-send -e -u low -i video-x-generic "Grabador de Pantalla" "Grabación iniciada (Pantalla Completa)"
    exec wf-recorder -f "$OUT"
fi

# Área: notifica solo si se seleccionó algo (ESC cancela)
GEOM=$(slurp)
[ -z "$GEOM" ] && exit 1
notify-send -e -u low -i video-x-generic "Grabador de Pantalla" "Grabación iniciada (Área)"
exec wf-recorder -g "$GEOM" -f "$OUT"