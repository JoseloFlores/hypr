#!/bin/bash

# 1. FORZAR EL ENTORNO
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

# 2. Sincronizar colores
"$HOME/.config/hypr/foot_sync.sh"

# 3. Iniciar el demonio en segundo plano
~/.cargo/bin/eww daemon

# 4. Esperar a que el demonio cargue
sleep 1

# 5. Abrir la barra
~/.cargo/bin/eww open bar
