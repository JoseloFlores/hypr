# QuickShell — shell por defecto (Waybar dormida)

QuickShell arranca por defecto vía `exec-once = ~/.config/hypr/quickshell-launcher.sh`
en `hyprland.conf`. Waybar queda instalada e intacta (`~/.config/waybar/`),
solo dormida (sin `exec-once` y con `waybar.service` deshabilitado).

## Probar / depurar QuickShell
```bash
~/.config/hypr/probar-quickshell.sh
```
Detiene Waybar+swaync en memoria y lanza
`QS_DEBUG=1 quickshell --path "$HOME/quickshell/shell.qml"`. Salir con `Ctrl+C`.

## Volver a Waybar
```bash
~/.config/hypr/volver-waybar.sh
```
Mata QuickShell y revive `swaync + waybar-launcher.sh`.

## Recargar QuickShell
```bash
~/.config/hypr/reload-quickshell.sh   # si existe (repo quickshell)
# o:
bind = $mainMod SHIFT, B   # recarga quickshell + notifica
```

## Menú de apagado (wlogout)
Los botones de apagado abren `wlogout` (Shutdown/Reboot/Suspend/Logout/Lock).
Si no está instalado a nivel sistema, `71-quickshell.sh` lo instala con apt;
como alternativa sin sudo funciona en `~/.local/bin/wlogout`.
Estilo en `~/.config/wlogout/` — se regenera solo con cada cambio de fondo.

## Fondo de pantalla
```bash
~/.config/hypr/set-wallpaper.sh /ruta/a/imagen.jpg
~/.config/hypr/set-wallpaper.sh --random [directorio]
# atajo: $mainMod SHIFT, W (aleatorio de ~/Imágenes/wallpapers/wallpaper/)
```
Sincroniza escritorio (swaybg) + bloqueo (hyprlock) + paleta pywal + wlogout.
El archivo canónico es `~/.config/hypr/wallpaper.jpg` (no reemplazar a mano).
