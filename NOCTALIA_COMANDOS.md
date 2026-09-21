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
