# Noctalia — shell por defecto

Noctalia v5 arranca por defecto vía `exec-once = noctalia` en
`hyprland.conf`. No usa Quickshell ni Waybar: es un binario nativo
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

## Fondo de pantalla

`~/.config/hypr/set-wallpaper.sh /ruta/a/imagen.jpg` o
`--random [directorio]`. Sincroniza `swaybg` + `hyprlock` +
paleta pywal (`foot`/`fuzzel`/`wlogout`). Atajo: `SUPER+SHIFT+W`.
El archivo canónico es `~/.config/hypr/wallpaper.jpg`.

## Ojo: template `foot` de Noctalia

No actives el template builtin `foot` (Settings → Templates):
genera `~/.config/foot/themes/noctalia` con cabecera `[colors-dark]`
y Foot falla al arrancar (`invalid section name`). Foot/Fuzzel ya
van por pywal (`foot_sync.sh`). Si lo activaste por error, quita
`"foot"` de `builtin_ids` en `~/.local/state/noctalia/settings.toml`;
Noctalia borra el archivo y el include solo.
