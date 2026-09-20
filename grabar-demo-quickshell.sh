#!/bin/bash
# grabar-demo-quickshell.sh — Graba demo de ventanas QuickShell en un WS vacío.
# Uso: ./grabar-demo-quickshell.sh [MONITOR] [SALIDA]
# Requiere: quickshell corriendo con IPC "windows" (temporal para la demo),
# wf-recorder, hyprctl, notify-send. Restaura tu WS/foco al terminar.
set -u

MON="${1:-eDP-1}"
OUT="${2:-/tmp/qs-demo.mp4}"
WS=9

QS_PID=$(pgrep -x quickshell | head -n1)
if [ -z "$QS_PID" ]; then
    echo "ERROR: quickshell no está corriendo" >&2
    exit 1
fi
call() { quickshell ipc --pid "$QS_PID" call windows "$@" >/dev/null 2>&1; }

PREV_WS=$(hyprctl activeworkspace -j | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
PREV_MON=$(hyprctl monitors -j | python3 -c "import json,sys; print([m['name'] for m in json.load(sys.stdin) if m.get('focused')][0])")

call hideAll
hyprctl dispatch focusmonitor "$MON" >/dev/null
hyprctl dispatch workspace "$WS" >/dev/null
sleep 1

rm -f "$OUT"
wf-recorder -o "$MON" -r 30 -f "$OUT" &
REC=$!
sleep 1

call toggle launcher;     sleep 2.2; call hideAll; sleep 0.6
call toggle controlcenter; sleep 2.2; call hideAll; sleep 0.6
notify-send "QuickShell" "Centro de notificaciones"
call toggle sidebar;       sleep 2.5; call hideAll; sleep 0.6
call toggle dashboard;     sleep 2.2; call hideAll; sleep 0.6

kill -INT "$REC"
wait "$REC" 2>/dev/null

hyprctl dispatch focusmonitor "$PREV_MON" >/dev/null
hyprctl dispatch workspace "$PREV_WS" >/dev/null
call hideAll

ls -la "$OUT"
