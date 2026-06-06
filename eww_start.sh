#!/bin/bash

# 1. FORZAR EL ENTORNO
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

# 2. Sincronizar colores
"$HOME/.config/hypr/foot_sync.sh"

# 3. Iniciar el demonio con variables de entorno para Wayland
export GDK_BACKEND=wayland
export GTK_THEME=Adwaita:dark
/home/jose/eww/target/release/eww daemon

# 4. Esperar a que el demonio cargue
sleep 1

# 6. Abrir la barra
/home/jose/eww/target/release/eww open eww-bar

