#!/bin/bash
# Eww starter — Wayland + tema sync — compatible con install.sh portátil
set -e

# 1. PATH: cargo + local + sistema
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# 2. Sincronizar colores foot/fuzzel con tema eww (no falla si no hay tema aún)
if [ -x "$HOME/.config/hypr/foot_sync.sh" ]; then
    "$HOME/.config/hypr/foot_sync.sh" || true
fi

# 3. Entorno Wayland
export GDK_BACKEND=wayland
export GTK_THEME=Adwaita:dark

# 4. Resolver binario eww: /usr/local/bin/eww (instalado por install.sh) o fallback legacy
EWW_BIN="/usr/local/bin/eww"
if [ ! -x "$EWW_BIN" ]; then
    if [ -x "$HOME/eww/target/release/eww" ]; then
        EWW_BIN="$HOME/eww/target/release/eww"
    else
        EWW_BIN="eww"
    fi
fi

# 5. Iniciar daemon si no corre
if ! pgrep -x eww >/dev/null 2>&1; then
    "$EWW_BIN" daemon &
    sleep 1
fi

# 6. Abrir barra + dashboard solar (eww de JoseloFlores/eww)
"$EWW_BIN" open eww-bar 2>/dev/null || true
"$EWW_BIN" open solar-dashboard 2>/dev/null || true
