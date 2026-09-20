# Hyprland • QuickShell • Debian 13/14 — Dotfiles Portables

> **Hyprland + QuickShell + Thunar + GNOME comforts (keyring/polkit)** listo para instalación limpia en **Debian 13 `trixie` / 14 `forky`** (sin entorno gráfico previo).  
> Resultado: sesión Wayland con blur corregido para Hyprland 0.55, QuickShell como shell, colores sincronizados (Foot/Fuzzel) y soporte multi-monitor/monitor único.
>
> Instalador **modular**: `install.sh` orquesta 12 módulos re-ejecutables en `install-scripts/`, con presets, `dry-run` y verificación final.

![Debian](https://img.shields.io/badge/Debian-13%2F14-A81D33?logo=debian)
![Hyprland](https://img.shields.io/badge/Hyprland-0.55-00A8F4?logo=hyprland)
![QuickShell](https://img.shields.io/badge/QuickShell-0.3-8DA68A)
![Portability](https://img.shields.io/badge/portable-%E2%9C%93-8DA68A)

## 👀 Vista previa

![QuickShell en acción](preview.mp4)

> Demo (~13 s, 2560x1600@30fps): launcher, centro de control, centro de
> notificaciones (con popup vía `notify-send`) y dashboard abriéndose sobre un
> escritorio vacío. Regrabable con [`grabar-demo-quickshell.sh`](grabar-demo-quickshell.sh).

---

## ✨ Características

- **Hyprland 0.55** con `hyprlock`, `hypridle`, `hyprpolkitagent`, `hyprland-guiutils`
- **19 temas sincronizados**: `ash-dark`, `ash-light`, `catppuccin-latte/mocha`, `dracula`, `everforest-dark/light`, `gruvbox-dark/light`, `kanagawa`, `monokai`, `nebula`, `nord`, `onedark`, `rose-pine/dawn`, `solarized-dark/light`, `tokyonight` → `foot` + `fuzzel` + `swaync` vía `foot_sync.sh`
- **QuickShell** `0.3` (trixie-backports) como barra — config en `~/quickshell` (clon del fork `JoseloFlores/quickshell`: compat Qt + ajustes propios commiteados), arranque con `quickshell-launcher.sh`, menú de apagado con `wlogout`, paleta pywal (`wal`+`colorz`) y fondo unificado con `set-wallpaper.sh` (SUPER+SHIFT+W aleatorio). Campana de notificaciones en barra, Logout/Sleep en el centro de control, Gaming Mode sin sudo (vía `power-profiles-daemon`) y DND por holders (Gaming+Focus sin pisarse). Guía en `QUICKSHELL_COMANDOS.md`
- **Instalador modular + presets + dry-run**: 12 módulos en `install-scripts/`, `preset.example.sh` / `preset.minimal.sh`, `./dry-run-build.sh` (PASS/FAIL por módulo), `99-final-check.sh` y `uninstall-lite.sh`
- **Portales**: `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` + `hyprland-portals.conf` (`default=hyprland;gtk`, `FileChooser=gtk`)
- **Gestión color/tema GTK Wayland**: `nwg-look` (reemplaza `lxappearance` que rompe Wayland) + `xdg-desktop-portal-gtk`
- **Comforts GNOME sin Mutter**: `hyprpolkitagent`, `gnome-keyring`, `udiskie`, `blueman-applet`, `swaync`, `wl-paste + cliphist`
- **Capturas / grabación**: `grim + slurp | swappy`, `wf-recorder` con toggle (SHIFT/CTRL+Print inician y detienen, vía `screen_recorder.sh`)
- **Hardware auto-detectado**: `intel-microcode`/`amd64-microcode`, `nvidia`/`amd`/`intel` VA-API, `firmware-linux-nonfree`, backlight con `brightnessctl -e4 -n2` + regla udev `90-backlight.rules` (grupo `video`)
- **Greetd + tuigreet** en `tty1` (`_greetd` en `video/render/input`, `Restart=always`)

---

## 📁 Estructura

```
hypr/
├── install.sh               # orquestador modular (--preset/--only/--skip/--dry-run/--check)
├── install.sh.monolitico.bak# respaldo del instalador monolítico original
├── preset.example.sh        # preset todo ON (NVIDIA_MODE=auto, SDDM=OFF)
├── preset.minimal.sh        # preset solo-dots para pruebas
├── dry-run-build.sh         # validación sin tocar sistema (PASS/FAIL por módulo)
├── uninstall-lite.sh        # revierte dots + timer (--full toca greetd/NM/udev)
├── install-scripts/         # un script por fase, re-ejecutables por separado
│   ├── Global_functions.sh  # logging Install-Logs/, apt resiliente, DRY_RUN
│   ├── 10-repos.sh / 20-drivers.sh / 30-base.sh / 40-hypr.sh
│   ├── 50-fonts.sh / 60-greetd.sh / 70-dots.sh / 71-quickshell.sh
│   └── 80-pam-portals.sh / 90-services.sh / 95-grub.sh / 99-final-check.sh
├── Install-Logs/            # un log por módulo + resumen dry-run (ignorado por git)
├── hyprland.conf            # config Hyprland 0.55 (layerrule nuevo)
├── hyprlock.conf
├── hypridle.conf
├── foot.ini / fuzzel.ini   # terminal y launcher (foot_sync.sh los re-colorea)
├── swaync_config.json / swaync_style.css
├── power_menu.sh / confirm_power.sh / foot_sync.sh
├── quickshell-launcher.sh / probar-quickshell.sh / grabar-demo-quickshell.sh
├── set-wallpaper.sh / QUICKSHELL_COMANDOS.md  # fondo unificado + guía quickshell
├── wlogout/                   # layout + style.css base (set-wallpaper.sh lo re-tintea)
├── wifi_click.sh / check_updates*.sh / auto_timezone.sh / screen_recorder.sh
├── wallpaper.jpg / preview.mp4
├── systemd/
│   └── user/
│       └── auto-timezone.{service,timer}  # detecta zona por IP (cada 30 min)
```

---

## ⚙️ Requisitos

- Debian 13 `trixie` o 14 `forky` minimal (sin `sddm`/`gdm`). El script parchea `contrib non-free non-free-firmware` y `debian.sources` (DEB822) y habilita `trixie-backports` si aplica.
- Conexión a `deb.debian.org`, `sudo` y `nproc`.

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

Relación módulo → fase (misma lógica del instalador original, partida 1:1):

| Módulo | Fase |
|---|---|
| `10-repos.sh` | `main contrib non-free non-free-firmware` + backports + APT resiliente |
| `20-drivers.sh` | microcode + `nvidia`/`amd`/`intel` VA-API + firmware (`NVIDIA_MODE=OFF` lo omite) |
| `30-base.sh` | ~60 paquetes + `xdg-desktop-portal-hyprland` + udev backlight + locales + `xdg-user-dirs` |
| `40-hypr.sh` | `hyprland hyprlock hypridle hyprpolkitagent hyprland-guiutils greetd tuigreet uwsm` |
| `50-fonts.sh` | `Meslo` + `SymbolsOnly` en `~/.local/share/fonts` (omite si ya descargadas) |
| `60-greetd.sh` | `config.toml` tuigreet + grupos `video/render/input/audio` (+ `input` opcional) |
| `70-dots.sh` | copia dots a `~/.config`, activa bloque NVIDIA si aplica, corre `foot_sync.sh`, habilita timer |
| `80-pam-portals.sh` | `pam_gnome_keyring` + `hyprland-portals.conf` |
| `90-services.sh` | NetworkManager gestionado + `enable NM/bluetooth/greetd`, `mask getty@tty1` |
| `95-grub.sh` | `desktop-base` + `update-grub` (omite si no hay `update-grub` o `INSTALL_GRUB_THEME=OFF`) |
| `99-final-check.sh` | versiones `quickshell/hyprland/tuigreet/portal`, bins en PATH, `hyprland --verify-config`, estado greetd/timer |

El instalador (comportamiento clásico, todo ON):

1. **Repos** → `main contrib non-free non-free-firmware` + backports
2. **Drivers** → microcode + `nvidia`/`amd`/`intel` + firmware
3. **Base** → `wget curl bc jq`, `network-manager`, `gvfs gvfs-backends gvfs-fuse gvfs-daemons udisks2 udiskie`, **`thunar thunar-archive-plugin thunar-volman xarchiver tumbler ffmpegthumbnailer`** (`INSTALL_THUNAR=OFF` lo omite), **`imv swayimg mpv`** (`INSTALL_MEDIA=OFF` lo omite), `pipewire wireplumber pavucontrol`, `bluez blueman`, `swaync gnome-calendar`, `wl-clipboard cliphist brightnessctl playerctl`, `foot fuzzel swaybg grim slurp swappy wf-recorder`, **`xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs`**, **`nwg-look`**, `fonts-jetbrains-mono`, `gnome-keyring seahorse polkitd`
   > Tras instalar `thunar` ejecuta automáticamente:
   > ```bash
   > LANG=es_ES.UTF-8 xdg-user-dirs-update --force
   > thunar -q
   > ```
   > para forzar `~/Imágenes`, `~/Documentos` etc. en español. `swayimg` es opcional en `trixie` (fallback a `imv` si no está).
4. **Hyprland stack** → `hyprland hyprlock hypridle hyprpolkitagent` + **`hyprland-guiutils`** + `greetd tuigreet` (desde `trixie-backports` si es trixie, nativo si es forky) + `xdg-desktop-portal-hyprland`
5. **Fuentes** → `Meslo Nerd Font` + `SymbolsOnly` en `~/.local/share/fonts`
6. **Greetd** → `tuigreet --time --remember --cmd Hyprland` (con vars NVIDIA si `GPU_TYPE=nvidia`)
7. **Dots** → copia `hyprland.conf`, `swaync/*`, `foot.ini`/`fuzzel.ini`, `systemd/user/*` a `~/.config` (rutas portables con `$HOME`/`~`, sin hardcode de usuario)
8. **PAM + Portales** → `pam_gnome_keyring`, `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`
9. **Servicios** → `systemctl enable greetd bluetooth NetworkManager`, `mask getty@tty1`
10. **GRUB gráfico** → instala `desktop-base` y ejecuta `update-grub` para activar el menú GRUB con el fondo azul artístico de Debian (si `update-grub` no existe, lo omite)
11. **Final check** → `99-final-check.sh`: si falta `hyprland`, la instalación se marca INCOMPLETA (`exit 1`)

> Post-instalación: `hyprland --verify-config` debe dar `config ok`.

### Desinstalación (lite y segura)

```bash
sudo ./uninstall-lite.sh          # revierte dots desplegados (con backup fechado) + timer
sudo ./uninstall-lite.sh --full   # además: disable greetd + borra overrides propios (portales, NM, udev)
```

No purga paquetes (si quieres quitarlos: `sudo apt autoremove hyprland` manual).

---

## 🖥️ Uso

- **SUPER + Return** → `$terminal` (`gnome-terminal` por defecto en `hyprland.conf:44`; el instalador provee **`foot`** en **SUPER + F**) | **SUPER + D** → `fuzzel` | **SUPER + X** → `$fileManager` (`nautilus` por defecto; el instalador provee **`thunar`**)
  > Si no tienes `gnome-terminal`/`nautilus`/`chrome`, edita `hyprland.conf:44-47` (`$terminal/$fileManager/$browser`) o instala esos paquetes.
- **SUPER + SHIFT + B** → recarga QuickShell + `notify-send`
- **Workspaces** → `SUPER + 1..0` / `SHIFT + 1..0` mover, `SUPER + scroll` navegar, `SUPER + S` scratchpad
- **Brillo/Volumen** → `XF86MonBrightnessUp/Down` (`brightnessctl -e4 -n2 set 5%±`), `XF86AudioRaise/LowerVolume` (`wpctl` 2%), scroll sobre brillo/volumen de la barra QuickShell
- **Capturas** → `Print` área/slurp, `ALT+Print` ventana activa (`hyprctl activewindow` + `jq`), `SUPER+Print` monitor
- **Grabación (toggle)** → `SHIFT+Print` área / `CTRL+Print` pantalla completa: primera pulsación inicia, segunda detiene (`screen_recorder.sh`, guarda en `~/Imágenes/Capturas`)
- **Power** → `SUPER + L` → `confirm_power.sh` / `wlogout`
- **Zona horaria automática** → `auto_timezone.sh` detecta tu zona por IP (`ipwho.is`/`ip-api.com`) y si cambia aplica `timedatectl set-timezone`:
  ```bash
  systemctl --user list-timers auto-timezone.timer          # estado
  systemctl --user enable --now auto-timezone.timer         # si no está activo
  ```

### Temas

```bash
~/.config/hypr/foot_sync.sh                       # sincroniza foot + fuzzel + swaync con el tema
# Tip Wayland: usa nwg-look en vez de lxappearance para GTK sin romper Wayland
nwg-look
```

---

## 🔧 Portabilidad

- **Monitores** → ejemplo `DP-3 1920x1080 0x0 1` + `eDP-1 2560x1600 160x1080 1.6` + fallback `monitor=,preferred,auto,1` comentado. Edita con `hyprctl monitors`.
- **Red/RTC** → `check_updates.sh` usa `xdg-user-dir PICTURES` y `return-type: json`.
- **Dots portables** → usan `$HOME`/`~` y `%h`; sin rutas `/home/<usuario>` hardcodeadas.
- **Debian trixie/forky** → detección `VERSION_CODENAME` + `ID=debian`, backports condicional. `NVIDIA_MODE=OFF` fuerza modo genérico aunque haya NVIDIA.
- **Presets** → `preset.example.sh` (todo ON) y `preset.minimal.sh` (solo dots). Cualquier variable `*_OFF` en un preset se traduce a `--skip` del módulo correspondiente.

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
- Fuentes [Nerd Fonts](https://www.nerdfonts.com) (Meslo, SymbolsOnly)
- Wallpaper `wallpaper.jpg` incluido
- Enfoque modular/preset/dry-run inspirado en [Debian-Hyprland (KooL Dots)](https://github.com/LinuxBeginnings/Debian-Hyprland) (adaptado a install `apt`, sin compilación desde source)

---

> **Tip:** `SUPER + SHIFT + B` recarga QuickShell. Para logs: `cat install.log`, `ls Install-Logs/`, `hyprland --verify-config`, `journalctl --user`.
