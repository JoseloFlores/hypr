#!/bin/bash

# Argumentos: $1 = Mensaje para el usuario, $2 = Comando a ejecutar

# Usamos zenity (ya que tienes GNOME instalado) para un diálogo fiable
if zenity --question --text="$1" --title="Confirmación" --width=300; then
    eval "$2"
fi
