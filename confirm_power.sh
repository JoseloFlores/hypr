#!/bin/bash

# Argumentos: $1 = Mensaje para el usuario, $2 = Comando a ejecutar

# Añadir rutas comunes al PATH para asegurar que comandos como systemctl o shutdown funcionen
export PATH=$PATH:/usr/bin:/usr/sbin:/bin:/sbin

# Usamos zenity (ya que tienes GNOME instalado) para un diálogo fiable
if zenity --question --text="$1" --title="Confirmación" --width=300; then
    echo "Ejecutando: $2" >> /tmp/power_menu.log
    eval "$2" >> /tmp/power_menu.log 2>&1
fi
