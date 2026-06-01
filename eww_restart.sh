#!/bin/bash

# 1. FORZAR EL ENTORNO (Esto arregla los widgets desplegables ciegos)
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

# 2. Sincronizar colores (Mantenemos tu configuración de Foot)
"$HOME/.config/hypr/foot_sync.sh"

# 3. Matar Eww de forma "civilizada" (Evita el error 'Scope not in graph')
# Usamos el comando nativo de eww en lugar de kill -9 para que limpie la memoria
~/.cargo/bin/eww kill

# Le damos un respiro para que cierre el socket correctamente
sleep 0.2 

# 4. Iniciar el demonio en segundo plano
~/.cargo/bin/eww daemon &

# 5. Esperar a que el demonio cargue su estado interno
sleep 0.2

# 6. Abrir la barra
~/.cargo/bin/eww open bar

# 7. Pequeña pausa adicional para que los widgets carguen
sleep 0.2

echo "Eww reiniciado con éxito y entorno cargado."
