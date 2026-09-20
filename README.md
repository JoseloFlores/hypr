# Hyprland • Noctalia • Debian 13/14 — Dotfiles Portables

> **Hyprland + Noctalia + Thunar + GNOME comforts (keyring/polkit)** listo para instalación limpia en **Debian 13 `trixie` / 14 `forky`** (sin entorno gráfico previo).
> Resultado: sesión Wayland con Noctalia v5 como shell (barra, launcher, notificaciones, control-center), colores sincronizados (Foot/Fuzzel) y soporte multi-monitor/monitor único.
>
> Instalador **modular**: `install.sh` orquesta 12 módulos re-ejecutables en `install-scripts/`, con presets, `dry-run` y verificación final.

![Debian](https://img.shields.io/badge/Debian-13%2F14-A81D33?logo=debian)
![Hyprland](https://img.shields.io/badge/Hyprland-0.55-00A8F4?logo=hyprland)
![Noctalia](https://img.shields.io/badge/Noctalia-v5-8DA68A)
![Portability](https://img.shields.io/badge/portable-%E2%9C%93-8DA68A)

---

## ✨ Características

- **Hyprland 0.55** con `hyprlock`, `hypridle`, `hyprpolkitagent`, `hyprland-guiutils`
- **Noctalia v5** como shell (repo APT `pkg.noctalia.dev`, suite `trixie`/`sid` según `VERSION_CODENAME`): barra solo en laptop (`noctalia/bar-monitors.toml`), arranque con `exec-once = noctalia`, binds IPC (`SUPER+Space` launcher, `SUPER+O` control-center, `SUPER+comma` settings, `ALT+Tab` switcher). Guía en `NOCTALIA_COMANDOS.md`
- **Theming único vía Noctalia** (`theme.source = wallpaper`): fondo + rotación sin `swaybg`, templates para GTK3/GTK4 (Thunar), bordes Hyprland, Foot, Fuzzel, wlogout, hyprlock y Neovim (base16, reemplaza gruvbox). Sin pywal. Detalle en `NOCTALIA_COMANDOS.md`
- **Instalador modular + presets + dry-run**: 12 módulos en `install-scripts/`, `preset.example.sh` / `preset.minimal.sh`, `./dry-run-build.sh` (PASS/FAIL por módulo), `99-final-check.sh` y `uninstall-lite.sh`
- **Portales**: `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` + `hyprland-portals.conf` (`default=hyprland;gtk`, `FileChooser=gtk`)
- **Gestión color/tema GTK Wayland**: `nwg-look` + `xdg-desktop-portal-gtk`
- **Comforts GNOME sin Mutter**: `hyprpolkitagent`, `gnome-keyring`, `udiskie`, `blueman-applet`, `wl-paste + cliphist` (notificaciones las sirve Noctalia)
- **Capturas / grabación**: `grim + slurp | swappy`, `wf-recorder` con toggle (SHIFT/CTRL+Print inician y detienen, vía `screen_recorder.sh`, guarda en `~/Pictures/Capturas`)
- **Hardware auto-detectado**: `intel-microcode`/`amd64-microcode`, `nvidia`/`amd`/`intel` VA-API, `firmware-linux-nonfree`, backlight con `brightnessctl -e4 -n2` + regla udev `90-backlight.rules` (grupo `video`)
- **Greetd + tuigreet** en `tty1` (`_greetd` en `video/render/input`, `Restart=always`)

---

## 📁 Estructura

```
hypr/
├── install.sh               # orquestador modular (--preset/--only/--skip/--dry-run/--check)
├── install.sh.monolitico.bak# respaldo del instalador monolítico original (histórico)
├── preset.example.sh        # preset todo ON (NVIDIA_MODE=auto, SDDM=OFF)
├── preset.minimal.sh        # preset solo-dots para pruebas
├── dry-run-build.sh         # validación sin tocar sistema (PASS/FAIL por módulo)
├── uninstall-lite.sh        # revierte dots + timer (--full toca greetd/NM/udev)
├── install-scripts/         # un script por fase, re-ejecutables por separado
│   ├── Global_functions.sh  # logging Install-Logs/, apt resiliente, DRY_RUN
│   ├── 10-repos.sh / 20-drivers.sh / 30-base.sh / 40-hypr.sh
│   ├── 50-fonts.sh / 60-greetd.sh / 70-dots.sh / 71-noctalia.sh
│   └── 80-pam-portals.sh / 90-services.sh / 95-grub.sh / 99-final-check.sh
├── Install-Logs/            # un log por módulo + resumen dry-run (ignorado por git)
├── hyprland.conf            # config Hyprland 0.55 + autostart/binds/reglas Noctalia
├── noctalia/
│   ├── bar-monitors.toml    # barra solo en eDP-1 (ajusta el match a tu conector)
│   ├── templates.toml       # fuente wallpaper + templates builtin/user + automation + hooks
│   ├── templates/           # inputs foot/fuzzel/wlogout/hyprlock/matugen (tokens Noctalia)
│   └── hooks/               # foot-apply, fuzzel-apply, sync-lock-wallpaper
├── hypridle.conf
├── foot.ini / fuzzel.ini   # estructura; colores via templates Noctalia
├── power_menu.sh / confirm_power.sh
├── NOCTALIA_COMANDOS.md     # guía noctalia (wallpapers, widgets, theming)
├── wlogout/                   # layout (style.css lo genera el template Noctalia)
├── auto_timezone.sh / screen_recorder.sh
├── wallpaper.jpg              # semilla inicial; en uso lo mantiene el hook wallpaper_changed
├── systemd/
│   └── user/
│       └── auto-timezone.{service,timer}  # detecta zona por IP (cada 30 min)
```

---

## ⚙️ Requisitos

- Debian 13 `trixie` o 14 `forky` minimal (sin `sddm`/`gdm`). El script parchea `contrib non-free non-free-firmware` y `debian.sources` (DEB822) y habilita `trixie-backports` si aplica.
- Conexión a `deb.debian.org` y `pkg.noctalia.dev`, `sudo` y `nproc`.

---

## 🚀 Instalación

```bash
git clone https://github.com/JoseloFlores/hypr.git
cd hypr
sudo ./install.sh   # logs en ./install.log + Install-Logs/
sudo reboot
```

### Modular: presets, módulos sueltos y simulación

```bash
sudo ./install.sh --preset preset.example.sh      # todo ON (comportamiento clásico)
sudo ./install.sh --only 70-dots,99-final-check   # solo re-desplegar dots + verificar
./install.sh --dry-run --only 70-dots             # simulación sin root ni cambios
./install.sh --check                              # lista módulos sin ejecutar
./dry-run-build.sh                                # PASS/FAIL de los 12 módulos
./dry-run-build.sh --only 70-dots,99-final-check
./dry-run-build.sh --skip 20-drivers,95-grub
sudo ./install-scripts/70-dots.sh                 # módulo suelto (cualquiera es re-ejecutable)
DRY_RUN=1 ./install-scripts/70-dots.sh            # módulo suelto en simulación
```

Relación módulo → fase:

| Módulo | Fase |
|---|---|
| `10-repos.sh` | `main contrib non-free non-free-firmware` + backports + APT resiliente |
| `20-drivers.sh` | microcode + `nvidia`/`amd`/`intel` VA-API + firmware (`NVIDIA_MODE=OFF` lo omite) |
| `30-base.sh` | ~60 paquetes + `xdg-desktop-portal-hyprland` + udev backlight + locales + `xdg-user-dirs` |
| `40-hypr.sh` | `hyprland hyprlock hypridle hyprpolkitagent hyprland-guiutils greetd tuigreet uwsm` |
| `50-fonts.sh` | `Meslo` + `SymbolsOnly` en `~/.local/share/fonts` (omite si ya descargadas) |
| `60-greetd.sh` | `config.toml` tuigreet + grupos `video/render/input/audio` (+ `input` opcional) |
| `70-dots.sh` | copia dots a `~/.config` (incluye `noctalia/*.toml` + `templates/` + `hooks/`), activa bloque NVIDIA si aplica, fija GTK oscuro base, habilita timer |
| `71-noctalia.sh` | repo APT Noctalia + `noctalia` + deps runtime (`upower power-profiles-daemon brightnessctl cliphist`) + `config validate` |
| `80-pam-portals.sh` | `pam_gnome_keyring` + `hyprland-portals.conf` |
| `90-services.sh` | NetworkManager gestionado + `enable NM/bluetooth/greetd`, `mask getty@tty1` |
| `95-grub.sh` | `desktop-base` + `update-grub` (omite si no hay `update-grub` o `INSTALL_GRUB_THEME=OFF`) |
| `99-final-check.sh` | `noctalia config validate`, bins en PATH, `hyprland --verify-config`, estado greetd/timer |

El instalador (comportamiento clásico, todo ON):

1. **Repos** → `main contrib non-free non-free-firmware` + backports
2. **Drivers** → microcode + `nvidia`/`amd`/`intel` + firmware
3. **Base** → `wget curl bc jq`, `network-manager`, `gvfs gvfs-backends gvfs-fuse gvfs-daemons udisks2 udiskie`, **`thunar thunar-archive-plugin thunar-volman xarchiver tumbler ffmpegthumbnailer`** (`INSTALL_THUNAR=OFF` lo omite), **`imv swayimg mpv`** (`INSTALL_MEDIA=OFF` lo omite), `pipewire wireplumber pavucontrol`, `bluez blueman`, `thunderbird`, `wl-clipboard cliphist brightnessctl playerctl`, `foot fuzzel swaybg grim slurp swappy wf-recorder`, **`xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs`**, **`nwg-look`**, `fonts-jetbrains-mono`, `gnome-keyring seahorse polkitd`
   > Tras instalar `thunar` ejecuta automáticamente:
   > ```bash
   > LANG=es_ES.UTF-8 xdg-user-dirs-update --force
   > thunar -q
   > ```
   > para forzar `~/Imágenes`, `~/Documentos` etc. en español. `swayimg` es opcional en `trixie` (fallback a `imv` si no está).
4. **Hyprland stack** → `hyprland hyprlock hypridle hyprpolkitagent` + **`hyprland-guiutils`** + `greetd tuigreet` (desde `trixie-backports` si es trixie, nativo si es forky) + `xdg-desktop-portal-hyprland`
5. **Fuentes** → `Meslo Nerd Font` + `SymbolsOnly` en `~/.local/share/fonts`
6. **Greetd** → `tuigreet --time --remember --cmd Hyprland` (con vars NVIDIA si `GPU_TYPE=nvidia`)
7. **Dots** → copia `hyprland.conf`, `noctalia/*.toml`, `foot.ini`/`fuzzel.ini`, `systemd/user/*` a `~/.config` (rutas portables con `$HOME`/`~`, sin hardcode de usuario; no pisa tu `~/.config/noctalia/` si ya existe)
8. **Noctalia** → repo APT + `noctalia` + `noctalia config validate`
9. **PAM + Portales** → `pam_gnome_keyring`, `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`
10. **Servicios** → `systemctl enable greetd bluetooth NetworkManager`, `mask getty@tty1`
11. **GRUB gráfico** → instala `desktop-base` y ejecuta `update-grub` (si `update-grub` no existe, lo omite)
12. **Final check** → `99-final-check.sh`: si falta `hyprland` o `noctalia`, la instalación se marca INCOMPLETA (`exit 1`)

> Post-instalación: `hyprland --verify-config` debe dar `config ok` y `noctalia config validate` debe dar `✓ Config is valid`.

### Desinstalación (lite y segura)

```bash
sudo ./uninstall-lite.sh          # revierte dots desplegados (con backup fechado) + timer
sudo ./uninstall-lite.sh --full   # además: disable greetd + borra overrides propios (portales, NM, udev)
```

No purga paquetes (si quieres quitarlos: `sudo apt autoremove hyprland noctalia` manual).

---

## 🖥️ Uso

- **SUPER + Return** → `$terminal` (`foot`) | **SUPER + F** → `foot` | **SUPER + D** → `fuzzel` | **SUPER + X** → `$fileManager` (`thunar`)
  > Si no tienes `chrome`, edita `hyprland.conf` (`$browser`) o instala ese paquete.
- **Noctalia** → `SUPER + Space` launcher, `SUPER + O` control-center, `SUPER + comma` settings, `ALT + Tab` switcher, `SUPER + SHIFT + B` reinicia Noctalia. Detalle en `NOCTALIA_COMANDOS.md`
- **Workspaces** → `SUPER + 1..0` / `SHIFT + 1..0` mover, `SUPER + scroll` navegar, `SUPER + S` scratchpad
- **Brillo/Volumen** → `XF86MonBrightnessUp/Down` (`brightnessctl -e4 -n2 set 5%±`), `XF86AudioRaise/LowerVolume` (`wpctl` 2%)
- **Capturas** → `Print` área/slurp, `ALT+Print` ventana activa (`hyprctl activewindow` + `jq`), `SUPER+Print` monitor
- **Grabación (toggle)** → `SHIFT+Print` área / `CTRL+Print` pantalla completa: primera pulsación inicia, segunda detiene (`screen_recorder.sh`, guarda en `~/Pictures/Capturas`)
- **Power** → `SUPER + L` → `confirm_power.sh` / `wlogout`
- **Zona horaria automática** → `auto_timezone.sh` detecta tu zona por IP (`ipwho.is`/`ip-api.com`) y si cambia aplica `timedatectl set-timezone` (Noctalia lee la zona en vivo, sin recargas):
  ```bash
  systemctl --user list-timers auto-timezone.timer          # estado
  systemctl --user enable --now auto-timezone.timer         # si no está activo
  ```

### Temas (todo vía Noctalia)

```bash
noctalia msg wallpaper-set /ruta/a/imagen.jpg   # fondo + paleta + apps
noctalia msg wallpaper-random                   # aleatorio (también SUPER+SHIFT+W)
noctalia msg templates-apply                    # re-renderizar templates
# Tip Wayland: usa nwg-look solo como visor; el tema GTK lo pone Noctalia
```

---

## 🔧 Portabilidad

- **Monitores** → ejemplo `DP-3 1920x1080 0x0 1` + `eDP-1 2560x1600 160x1080 1.67` + fallback `monitor=,preferred,auto,1` comentado. Edita con `hyprctl monitors`. Barra Noctalia solo en laptop vía `noctalia/bar-monitors.toml` (ajusta `match` a tu conector).
- **Dots portables** → usan `$HOME`/`~` y `%h`; sin rutas `/home/<usuario>` hardcodeadas.
- **Debian trixie/forky/sid** → detección `VERSION_CODENAME` + `ID=debian`, backports condicional. `NVIDIA_MODE=OFF` fuerza modo genérico aunque haya NVIDIA. El módulo Noctalia elige suite `trixie`/`sid` según codename.
- **Presets** → `preset.example.sh` (todo ON) y `preset.minimal.sh` (solo dots). Cualquier variable `*_OFF` en un preset se traduce a `--skip` del módulo correspondiente (`NOCTALIA=OFF` omite el shell).

---

## 🩹 Solución de problemas

**Brillo scroll `Permission denied`**
> `brightnessctl` necesita `video`. El instalador añade a `video/render/input` pero `/sys/class/backlight/.../brightness` es `root:root`. Aplica:
> ```bash
> echo 'SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"' | sudo tee /etc/udev/rules.d/90-backlight.rules
> sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=backlight --action=add
> sudo chgrp video /sys/class/backlight/intel_backlight/brightness; sudo chmod g+w "$_"
> ```
> (El módulo `30-base.sh` ya despliega esa regla; `99-final-check.sh` no la verifica, revisa el log del módulo.)

**Hora en UTC en vez de local**
> Sistema debe estar en tu zona (`timedatectl`).
> Si viajas: `sudo timedatectl set-timezone America/Montevideo`. El timer `auto-timezone` lo hace solo cada 30 min (requiere sesión de usuario activa para `systemctl --user enable`; si el instalador avisó `sin sesión activa`, actívalo en el primer login).

**Noctalia no arranca / barra ausente**
> ```bash
> noctalia config validate
> tail -n 50 ~/.cache/noctalia/noctalia.log
> hyprctl layers | grep noctalia
> noctalia msg config-reload
> ```
> Si tu `~/.config/noctalia/` ya existía, el instalador no la pisa: compara con `noctalia/bar-monitors.toml` del repo. Si la GUI ignora tu TOML, revisa overrides en `~/.local/state/noctalia/settings.toml`.

**Un módulo falló / quiero reintentar solo una parte**
> ```bash
> ./dry-run-build.sh --only 70-dots,99-final-check   # reproduce sin tocar nada
> sudo ./install.sh --only 70-dots,99-final-check    # re-ejecuta solo eso
> cat Install-Logs/70-dots-*.log                    # log del módulo
> ```

---

## 📜 Licencia

Dotfiles bajo MIT. Hyprland BSD-3.

## 🙏 Créditos

- [Hyprland](https://hypr.land) vaxerski & contributors
- [Noctalia](https://noctalia.dev) noctalia-dev & contributors
- Fuentes [Nerd Fonts](https://www.nerdfonts.com) (Meslo, SymbolsOnly)
- Wallpaper `wallpaper.jpg` incluido como semilla (en uso lo sincroniza el hook de Noctalia)
- Enfoque modular/preset/dry-run inspirado en [Debian-Hyprland (KooL Dots)](https://github.com/LinuxBeginnings/Debian-Hyprland) (adaptado a install `apt`, sin compilación desde source)

---

> **Tip:** `SUPER + SHIFT + B` reinicia Noctalia. Para logs: `cat install.log`, `ls Install-Logs/`, `hyprland --verify-config`, `noctalia config validate`, `tail ~/.cache/noctalia/noctalia.log`.
