#!/bin/bash
# Reinicio limpio de eww — mata daemon y reabre barra+dashboard
set -e
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

EWW_BIN="/usr/local/bin/eww"
if [ ! -x "$EWW_BIN" ] && [ -x "$HOME/eww/target/release/eww" ]; then
    EWW_BIN="$HOME/eww/target/release/eww"
fi
[ -x "$EWW_BIN" ] || EWW_BIN="eww"

# Sincronizar colores antes de reiniciar
[ -x "$HOME/.config/hypr/foot_sync.sh" ] && "$HOME/.config/hypr/foot_sync.sh" || true

pkill -9 -x eww 2>/dev/null || true
sleep 1
if ! pgrep -x eww >/dev/null 2>&1; then
    GDK_BACKEND=wayland GTK_THEME=Adwaita:dark "$EWW_BIN" daemon &
    sleep 1
fi
"$EWW_BIN" open eww-bar 2>/dev/null || true
"$EWW_BIN" open solar-dashboard 2>/dev/null || true
