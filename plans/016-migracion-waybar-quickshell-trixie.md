# Plan explícito: Waybar → QuickShell completo en Trixie + backports

> No ejecutar hoy. Diseñado para ejecución diferida paso a paso, con rollback a Waybar en cada fase.
> Estado detectado 2026-09-16: `Trixie Qt 6.8.2`, `hyprland 0.55.2~bpo13+1 OK`, `quickshell NO instalado`, `qml6-module-qtquick-effects NO instalado`, `wal NO`, `~/.cache/wal/colors.json NO existe`, `swaync activo`, `NM managed + wifi conectado`, `backlight intel_backlight + grupo video OK`, `foot OK`, `fuentes Inter/Material Icons NO`.

## Fase 0 – Backup y foto del estado actual (5 min, cero riesgo)

```bash
mkdir -p ~/backup-waybar-qs ~/.config/quickshell
cp ~/.config/waybar/config ~/backup-waybar-qs/waybar-config.bak
cp ~/.config/waybar/config.jsonc ~/backup-waybar-qs/waybar-config.jsonc.bak
cp ~/.config/hypr/hyprland.conf ~/backup-waybar-qs/hyprland.conf.bak
cp /home/jo/quickshell/shell.json ~/backup-waybar-qs/shell.json.orig
hyprctl monitors > ~/backup-waybar-qs/hyprctl-monitors.txt
nmcli dev status > ~/backup-waybar-qs/nm-status.txt
ls /sys/class/backlight/ > ~/backup-waybar-qs/backlight.txt
```

No tocar `exec-once = ~/.config/hypr/waybar-launcher.sh` todavía.

## Fase 1 – Instalar dependencias Debian (15 min)

```bash
sudo apt update
# QuickShell + Hyprland desde backports (Hyprland ya lo tienes, QuickShell te falta)
sudo apt install -t trixie-backports quickshell
# Qt/QML que exige el repo (nombres Debian, no Arch)
sudo apt install qt6-base qt6-declarative qt6-svg qt6-wayland \
  qml6-module-qtquick qml6-module-qtquick-layouts qml6-module-qtquick-controls \
  qml6-module-qtquick-effects \
  grim slurp wl-clipboard jq libnotify-bin wf-recorder playerctl brightnessctl \
  network-manager pavucontrol blueman power-profiles-daemon upower \
  foot fonts-inter fonts-font-awesome fonts-jetbrains-mono
# Verificar
quickshell --version
dpkg -l | grep qml6-module-qtquick-effects
```

Qué **NO** instalar: `wlogout` (no está en main, el repo lo usa en `ControlCenterWindow.qml:44` pero es opcional), `pamixer` (listado en `setup.sh` pero código usa `wpctl`, no lo necesitas), `radeontop` (no en main, solo afecta a `SystemUsage.qml` AMD).

## Fase 2 – Parche obligatorio Qt 6.8 (bloqueante, 10 min)

Sin esto no arranca en Trixie aunque todo lo demás esté bien. El repo pinea `6.10` en ~60 ficheros (`shell.qml:7`, `Bar.qml:2-4`, `BarWrapper.qml:3`, `LauncherWindow`, `Dashboard`, etc.).

```bash
# En /home/jo/quickshell, quitar versión de imports:
grep -rl 'import QtQuick 6\.10\|import QtQuick\.Layouts 6\.10\|import QtQuick\.Controls 6\.10' --include='*.qml' .
# Reemplazo esperado (hacer con editor, no sed a ciegas en build):
# import QtQuick 6.10 -> import QtQuick
# import QtQuick.Layouts 6.10 -> import QtQuick.Layouts
# import QtQuick.Controls 6.10 -> import QtQuick.Controls
# Verificar que no quede ningún 6.10:
grep -r '6\.10' --include='*.qml' . | wc -l  # debe dar 0
```

No tocar `import QtQuick.Effects` (sin versión, correcto) ni `Quickshell.*`.

## Fase 3 – Pywal + fuentes (10 min, sin esto se ve sin color/tofu)

```bash
# Pywal no existe en Debian -> pipx
sudo apt install pipx
pipx install pywal16
export PATH="$HOME/.local/bin:$PATH"
~/.local/bin/wal -i ~/.config/hypr/wallpaper.jpg
ls ~/.cache/wal/colors.json  # debe existir
# Fuentes faltantes (Inter OK por apt, Material Icons + Nerd manual):
# 1. fonts-inter ya instalado en Fase 1
# 2. Material Design Icons: descargar MaterialDesignIconsDesktop.ttf desde
#    https://github.com/templarian/MaterialDesign-Fonts -> ~/.local/share/fonts/ + fc-cache -fv
# 3. JetBrainsMono Nerd: ya tienes fonts-jetbrains-mono, si ves tofu en iconos (waybar usa FontAwesome/Nerd),
#    descargar JetBrainsMonoNerdFont-Regular.ttf a ~/.local/share/fonts/
fc-list | grep -iE 'inter|material.*icon|jetbrains|fontawesome'
```

## Fase 4 – Adaptar `shell.json` a tu entorno real (5 min)

Editar `/home/jo/quickshell/shell.json` (conservar orig en backup):

* `paths.screenshotsDir`: tienes `~/Pictures/Capturas` en `hyprland.conf:382` (grim|swappy). Quickshell trae `~/Pictures/Screenshots`. Unifica a `~/Pictures/Capturas` o tendrás dos carpetas.
* `launcher.terminalCommand`: repo trae `["foot"]`. Tu `hyprland.conf:44` usa `gnome-terminal`, pero `foot` sí lo tienes y `wifi_click.sh:11` usa `foot -e`. Deja `["foot"]` para la prueba, cambia luego si prefieres `gnome-terminal`.
* `launcher.favorites`: trae `firefox,zen-browser,thunar,code,kitty,Alacritty`. Tú usas `google-chrome-stable, nautilus, gnome-terminal, fuzzel`. Añade `google-chrome-stable` y `nautilus` para que el launcher los encuentre.
* `notifications.registerServer`: deja `false` en la primera prueba (tienes `exec-once = swaync &` en `hyprland.conf:67`). Si lo pones `true` duplicarás con swaync. Solo pon `true` cuando quieras jubilar swaync.
* `appearance.fontFamily`: deja `Inter`, `materialIconFont`: deja `Material Design Icons` tras Fase 3.

## Fase 5 – Integración Hyprland sin romper Waybar (5 min, reversible)

```bash
# 1. Añadir al final de ~/.config/hypr/hyprland.conf (NO borrar waybar aún):
# source = ~/.config/quickshell/hyprland-layer-config.conf
# 2. Recargar hyprland: hyprctl reload
# Contenido de ese conf: layerrule blur/ignore_alpha para quickshell.*,
# animation layersIn/Out, windowrule float/no_blur para quickshell.
# Tus layerrule waybar (hyprland.conf:471-476) no se tocan.
```

## Fase 6 – Prueba en paralelo (20 min, Waybar sigue vivo)

```bash
QS_DEBUG=1 quickshell --path /home/jo/quickshell/shell.qml
# O si tu quickshell backport usa qs:
QS_DEBUG=1 qs --path /home/jo/quickshell/shell.qml
```

Checklist de validación en este orden:

1. Barra aparece por monitor (`BarWrapper.qml:58 Variants Quickshell.screens`, bueno para tu `eDP-1+DP-3`, a diferencia de Waybar `output: eDP-1` vs `*`).
2. Workspaces Hyprland click + scroll (`Workspaces.qml` vs tu `hyprctl dispatch workspace`).
3. Reloj: Waybar abre `swaync-client -t -sw || thunderbird -calendar`. Quickshell `Clock.qml` abre launcher/controlcenter/sidebar/dashboard, **no** Thunderbird. Pérdida conocida, decide si te compensa.
4. Audio: `wpctl` OK, click abre `pavucontrol` igual que Waybar. Scroll volumen igual.
5. Red: `nmcli` OK (tu wifi está managed). Falta tu lógica custom `waybar_network.sh` (VPN+Tailscale+unmanaged fallback) y `wifi_click.sh` (diagnóstico unmanaged). Quickshell `NetworkPanel` no sabe de VPN/Tailscale. Mantén tus scripts para diagnóstico aunque no salgan en la barra.
6. BT: `blueman-manager` igual que Waybar. `bluetoothctl power toggle` (click-derecha Waybar) no existe en Quickshell, solo panel.
7. Batería `UPower` OK. Brillo `brightnessctl` OK (estás en grupo `video`, no necesitas el sudoers `ALL ALL` de `setup.sh:112`, ignóralo).
8. Tray: `SystemTray.qml` vs Waybar tray. Verifica `blueman-applet`, `udiskie -t`, `thunderbird`.
9. OSD volumen/brillo con teclas `XF86*` (tus binds `hyprland.conf:353-358` siguen valiendo).
10. Screenshots: tus binds usan `grim -g "$(slurp)" - | swappy -f -` y `hyprctl activewindow -j | jq`. Quickshell `Screenshot.qml` usa `grim <file> + wl-copy + notify-send` y `wf-recorder -c h264_vaapi -d /dev/dri/renderD128` (tu `screen_recorder.sh` usa `wf-recorder -f/-g` sin vaapi, más portable). Espera doble sistema de capturas hasta que elijas uno.
11. Power: Waybar usa `confirm_power.sh` (zenity) + `power_menu.sh` (fuzzel) + `hyprctl dispatch exit`. Quickshell `PowerButton/SettingsSection` hace `systemctl poweroff/suspend/reboot + hyprctl dispatch exit` directo sin confirmación. Cambio de comportamiento a asumir.

Si algo falla: `pkill -x quickshell; ~/.config/hypr/waybar-launcher.sh &` y sigues con Waybar.

## Fase 7 – Cutover solo si Fase 6 verde (5 min)

1. En `hyprland.conf`: comenta `exec-once = ~/.config/hypr/waybar-launcher.sh`, añade `exec-once = quickshell --path /home/jo/quickshell/shell.qml` (o `qs ...` según binario backport).
2. Si `registerServer:true`, comenta `exec-once = swaync &`. Si `false`, deja swaync.
3. Reboot o `hyprctl dispatch exit` + login. Mantén `~/backup-waybar-qs/` 1 semana.

Rollback instantáneo: revertir esos dos `exec-once` + `hyprctl reload`.

## Mapeo de tus customs Waybar → QuickShell (para no perder nada)

| Waybar actual | QuickShell | Acción |
|---|---|---|
| `custom/updates check_updates.sh interval 3600 + click sudo apt upgrade + SIGRTMIN+8` | No existe | Mantener script manual o pedir port como módulo. No bloquea. |
| `custom/network waybar_network.sh VPN/WiFi/Tailscale/unmanaged` | `Network.qml + NetworkPanel` solo NM básico | Pérdida parcial VPN/Tailscale tooltip. Guarda scripts para diagnóstico. |
| `clock on-click swaync-client/thunderbird -calendar` | `Clock.qml` abre launcher/dashboard | Pérdida Thunderbird-calendario. Workaround: bind propio `SUPER+T` ya lo tienes. |
| `group/power drawer + zenity confirm + fuzzel menu` | `PowerButton` directo sin confirm | Acostumbrarse o pedir confirm dialog. |
| `pulseaudio scroll-step 2 max 100` vs `Audio.qml hasta 150%` | Volumen puede subir a 150% | Ojo a picos, baja a 100% si te molesta. |
| `backlight scroll 5%` | `Brightness.qml brightnessctl set %` | Equivalente. |
| `output eDP-1` (config) vs `*` (config.jsonc) | `Quickshell.screens` per-monitor | Mejor que Waybar, verifica en DP-3. |
