# Project Instructions - Hyprland + GNOME (Debian 13)

Este proyecto utiliza Hyprland sobre una base de Debian con GNOME instalado. Para garantizar la compatibilidad y funcionalidad de los módulos de Waybar, se deben seguir las siguientes convenciones:

## Herramientas de Gestión

- **Red (WiFi/Ethernet/VPN):** Utilizar `nmtui` ejecutado en la terminal `foot` para la gestión de conexiones. 
    - Se utiliza un script personalizado (`~/.config/hypr/waybar_network.sh`) para unificar los iconos de WiFi y VPN en Waybar.
    - El script ignora automáticamente servicios de red persistentes como **Tailscale** para que el icono de VPN solo se muestre cuando hay una conexión de túnel activa y manual.
- **Bluetooth:** Utilizar `blueman-manager` para la gestión gráfica de dispositivos. El módulo de Waybar está configurado para ser minimalista, mostrando solo iconos de estado (Conectado/Encendido/Apagado) y ocultando el nombre del dispositivo en el tooltip.
- **Audio:** Utilizar `XDG_CURRENT_DESKTOP=GNOME gnome-control-center sound` para la configuración de audio. Los iconos han sido actualizados a versiones modernas de Nerd Fonts para evitar errores de renderizado.
- **Confirmaciones:** Los diálogos de confirmación del menú de energía (`confirm_power.sh`) deben utilizar `zenity --question` por su fiabilidad en este entorno.
- **Bloqueo de Pantalla:** El botón de bloqueo debe llamar directamente a `hyprlock`.

## Solución de Problemas

### Iconos de Tray Ausentes (Spotify, Discord, etc.)
Si aplicaciones como Spotify muestran un espacio vacío en el Tray:
1. Asegurarse de tener `libayatana-appindicator3-1` instalado.
2. Ejecutar la aplicación sin forzar Wayland nativo (dejar que use XWayland para el tray).
3. Reiniciar Waybar con `Super + Shift + B`.

## Requisitos de Entorno

- **Polkit Agent:** Se requiere un agente de autenticación activo. Se recomienda `hyprpolkitagent` (instalado y gestionado vía systemd). Debe iniciarse con `exec-once = systemctl --user start hyprpolkitagent` en `hyprland.conf`.
- **Variables de Entorno:** Para herramientas de GNOME como `gnome-control-center`, es necesario prefijar con `XDG_CURRENT_DESKTOP=GNOME` para habilitar paneles específicos.
