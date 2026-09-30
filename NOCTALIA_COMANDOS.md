# Noctalia — shell por defecto

Noctalia v5 arranca por defecto vía `exec-once = noctalia` en
`hyprland.conf`. Es un binario nativo
(`apt install noctalia` desde su repo APT).

La config vive en `~/.config/noctalia/*.toml` (este repo despliega
`noctalia/bar-monitors.toml`). Lo que cambies en la GUI
(`SUPER+comma`) se guarda en `~/.local/state/noctalia/settings.toml`
y **gana** sobre tus archivos manuales.

## Atajos (ver `hyprland.conf`)

| Bind | Acción |
|---|---|
| `SUPER + Space` | launcher (`noctalia msg panel-toggle launcher`) |
| `SUPER + O` | control-center (la doc usa `SUPER+S`, aquí es scratchpad) |
| `SUPER + comma` | settings (`noctalia msg settings-toggle`) |
| `ALT + Tab` | window-switcher |
| `SUPER + SHIFT + B` | reinicia Noctalia + `notify-send` |

## Comandos útiles

```bash
noctalia msg panel-toggle launcher      # abrir/cerrar launcher
noctalia msg panel-toggle control-center
noctalia msg bar-toggle                 # mostrar/ocultar barras
noctalia msg config-reload              # recargar config tras editar TOML
noctalia config validate                # validar ~/.config/noctalia/
noctalia config export > noctalia-config.toml   # ver config efectiva
tail -f ~/.cache/noctalia/noctalia.log  # logs
hyprctl layers | grep noctalia          # capas activas por monitor
```

## Widgets

`SUPER+comma` → **Bar → Bar Widgets** (arrastrar/reordenar).
Click-medio en un widget abre su configuración directa.
En TOML: listas `start/center/end` bajo `[bar.default]` y ajustes
por widget bajo `[widget.<nombre>]`. Tras editar:
`noctalia config validate && noctalia msg config-reload`.

## Captura (foto + vídeo en un solo widget)

Widget `capture` (plugin local `jo/capture`, `noctalia/plugins/capture/`):
reemplaza al builtin `screenshot`.

| Gesto | Acción | Destino |
|---|---|---|
| click izq | foto región (`screenshot-region`, respeta `[shell.screenshot]`) | según tu política de screenshot |
| click medio | foto pantalla (`screenshot-fullscreen`) | idem |
| click der | vídeo toggle: región (slurp) si idle, detener si grabando | `~/Vídeos/Recordings/Video_*.mp4` |

Backend vídeo `wf-recorder` con fixes integrados (codec `libx264`, `-o` monitor
con foco en multi-monitor, espera ~6s al muxear tras SIGINT). Sin audio,
30 fps por defecto (cambia en Settings → Plugins → Capture).

```bash
~/.config/hypr/capture-apply.sh   # (en este repo: noctalia/capture-apply.sh) re-despliega plugin + merge barra (idempotente)
noctalia msg plugin jo/capture:service all record-fullscreen
noctalia msg plugin jo/capture:service all select-region   # alias: toggle-region
noctalia msg plugin jo/capture:service all stop
noctalia msg plugin jo/capture:capture focused photo            # foto región
noctalia msg plugin jo/capture:capture focused photo-fullscreen # foto pantalla
noctalia msg plugin jo/capture:capture focused video            # = click-der
```

Notas:
- El plugin oficial `noctalia/screen_recorder` (gpu-screen-recorder) **no va en este HW**: el portal no entrega frames dmabuf/GPU y el Flatpak no conecta su servidor KMS. No instalarlo en reinstall.
- El community `h-jangra/region-recorder` queda jubilado (su lógica vive ahora en `jo/capture:service` con el parche ya integrado). No re-ejecutar `noctalia-plugins-apply.sh` para region-recorder.
- Fallback sin plugin: `screen_recorder.sh` (`Print+SHIFT` = área, `Print+CTRL` = full, `~/.config/hypr/screen_recorder.sh area|full`) → `~/Pictures/Capturas/`. Sigue operativo.

## Fondo de pantalla

El fondo lo dibuja Noctalia (sin `swaybg`):
`SUPER+Space` → widget wallpaper, o `SUPER+SHIFT+W` (aleatorio).
Rotación automática cada 30 min desde `~/Imágenes/wallpapers/wallpaper`
(`[wallpaper.automation]` en `noctalia/templates.toml`).
`~/.config/hypr/wallpaper.jpg` lo mantiene el hook `wallpaper_changed`
(es la imagen que usa hyprlock).

## Theming: Noctalia manda en todo

Fuente única: `theme.source = "wallpaper"` (paleta del fondo actual).
Templates activos (`noctalia/templates.toml`):

| Destino | Template | Notas |
|---|---|---|
| GTK3/GTK4 + Thunar | builtins `gtk3`/`gtk4` | base `Adwaita-dark` (`adw-gtk3` no está en Debian; opcional manual desde GitHub) |
| Bordes Hyprland | builtin `hyprland` | genera `~/.config/hypr/noctalia.conf` + `source` (no tocar ese archivo) |
| Foot | user `foot` | el builtin genera `[colors-dark]` roto; este genera `[colors]` bien |
| wlogout | user `wlogout` | `style.css` generado (iconos en `~/.local/share/wlogout/icons/`) |
| hyprlock | user `hyprlock` | `hyprlock.conf` generado (fondo = `wallpaper.jpg` del hook) |
| Neovim | user `nvim_base16` | `matugen.lua` + plugin `base16-nvim` (reemplaza gruvbox) |

```bash
noctalia msg templates-apply   # re-renderizar tras editar inputs
noctalia msg wallpaper-random  # fondo aleatorio
noctalia msg wallpaper-set /ruta/a/img.jpg
```

## Ojo: template builtin `foot` de Noctalia

No actives el builtin `foot` (Settings → Templates):
genera `~/.config/foot/themes/noctalia` con cabecera `[colors-dark]`
y Foot falla al arrancar (`invalid section name`). Foot va por el
user-template propio (`noctalia/templates/foot.ini`, cabecera `[colors]`
correcta). Si activaste el builtin por error, quítalo de `builtin_ids`
en `~/.local/state/noctalia/settings.toml`; Noctalia limpia solo.
