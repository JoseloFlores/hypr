# QuickShell — shell por defecto (Waybar dormida)

QuickShell arranca por defecto vía `exec-once = ~/.config/hypr/quickshell-launcher.sh`
en `hyprland.conf`. Waybar queda instalada e intacta (`~/.config/waybar/`),
solo dormida (sin `exec-once` y con `waybar.service` deshabilitado).
Código en `~/quickshell` (clon del fork `JoseloFlores/quickshell`); la config
activa vive en `~/.config/quickshell/shell.json` + `settings.json`.

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
~/quickshell/reload-quickshell.sh
# o:
bind = $mainMod SHIFT, B   # recarga quickshell + notifica
```

## Botones de la barra
- **Reloj**: click izquierdo abre el launcher, click derecho el dashboard.
- **Campana** (powerPill, con badge de no-leídas): abre el centro de
  notificaciones (sidebar). Abrirlo **no** borra el badge: se limpia con
  Clear/Dismiss/Delete.
- **Caffeine / DND** (indicadores): el click **alterna** el estado.
- **Brillo**: click alterna 100% ↔ 35%; la rueda ajusta fino (igual en el
  slider del ControlCenter).
- **Updates**: click abre la actualización APT en `foot`; la rueda refresca.

## Centro de control
Header con Settings (`nm-connection-editor`), Lock, **Logout**
(`hyprctl dispatch exit`), **Sleep** (`systemctl suspend`) y Power (`wlogout`).
QuickToggles: Wi-Fi, Bluetooth, DND, Caffeine, **Gaming Mode**, Focus Mode
(timer 25 min), Screenshot (pantalla completa), Updates, Record, Open Captures.

## Gaming Mode (sin sudo)
Activa perfil `performance` vía `power-profiles-daemon` + inhibe idle + pide
DND. Al apagarlo vuelve a `balanced`. **Ya no toca sysfs**: no hay que
configurar `sudoers` para `scaling_governor`.
DND es por *holders* (`gaming`, `focus`): Gaming y Focus pueden coexistir sin
pisarse; se apaga solo cuando nadie lo pide. Los toggles manuales de DND se
respetan siempre.

## Desactivar ventanas
`~/.config/quickshell/shell.json`: `launcher.enabled`, `sidebar.enabled`,
`dashboard.enabled` y `controlcenter.enabled`. Los botones de la barra
respetan estos flags (click sin efecto si la ventana está desactivada).
`settings.json` solo guarda Focus Mode (`focusModeEnabled`,
`focusModeMinutesLeft`).

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
