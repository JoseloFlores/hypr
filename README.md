# Hyprland • Waybar • Debian 13/14 — Dotfiles Portables

> **Hyprland + Waybar + Thunar + GNOME comforts (keyring/polkit)** listo para instalación limpia en **Debian 13 `trixie` / 14 `forky`** (sin entorno gráfico previo).  
> Resultado: sesión Wayland con blur corregido para Hyprland 0.55, waybar en píldoras transparentes, colores sincronizados (Foot/Fuzzel) y soporte multi-monitor/monitor único.

![Debian](https://img.shields.io/badge/Debian-13%2F14-A81D33?logo=debian)
![Hyprland](https://img.shields.io/badge/Hyprland-0.55-00A8F4?logo=hyprland)
![Waybar](https://img.shields.io/badge/Waybar-0.12%20%2F%200.15-7AA2F7)
![Portability](https://img.shields.io/badge/portable-%E2%9C%93-8DA68A)

---

## ✨ Características

- **Hyprland 0.55** con `hyprlock`, `hypridle`, `hyprpolkitagent`, `hyprland-guiutils`
- **Waybar** `0.12` (trixie) / `0.15` (forky) — módulos `hyprland/workspaces`, `clock`, `pulseaudio`, `custom/network` (VPN+WiFi), `bluetooth`, `battery`, `backlight`, `group/power` drawer
- **Barra en píldoras**: `window#waybar` transparente, cada módulo `rgba(35,37,48,0.6)` con `blur = false` (fondo entre pills transparente, sin desenfoque)
- **Workspaces** sin morado — `active` y `visible` en gris `rgba(200,201,209,0.15)` sobre `fg #c8c9d1`
- **Reloj** `GMT-3` automático: `locale: es_AR.UTF-8`, `timezone: ""` (sigue `/etc/localtime` → `America/Argentina/Buenos_Aires`), `format: " {0:%H:%M}   {0:%d/%m}"` compatible con Waybar 0.12 (`fmt` requiere `{0:...}` para 2 placeholders)
- **Tema sincronizado**: `waybar/themes/*.css` (`ash-dark`, `ash-light`, `nebula`, `tokyonight`) → `waybar/style.css` + `foot` + `fuzzel` vía `waybar/scripts/waybar-theme.sh` y `foot_sync.sh`
- **Portales**: `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` + `hyprland-portals.conf` (`default=hyprland;gtk`, `FileChooser=gtk`)
- **Gestión color/tema GTK Wayland**: `nwg-look` (reemplaza `lxappearance` que rompe Wayland) + `xdg-desktop-portal-gtk`
- **Comforts GNOME sin Mutter**: `hyprpolkitagent`, `gnome-keyring`, `udiskie`, `blueman-applet`, `swaync`, `wl-paste + cliphist`
- **Capturas / grabación**: `grim + slurp | swappy`, `wf-recorder` (Print / SHIFT+Print / CTRL+Print)
- **Hardware auto-detectado**: `intel-microcode`/`amd64-microcode`, `nvidia`/`amd`/`intel` VA-API, `firmware-linux-nonfree`, backlight `intel_backlight` con `brightnessctl -d intel_backlight -e4 -n2`
- **Greetd + tuigreet** en `tty1` (autologin `_greetd` en `video/render/input`)

---

## 📁 Estructura

```
hypr/
├── install.sh               # instalador idempotente Debian 13/14
├── hyprland.conf            # config Hyprland 0.55 (layerrule nuevo)
├── hyprlock.conf
├── hypridle.conf
├── wallpaper.jpg
├── power_menu.sh / confirm_power.sh / foot_sync.sh / waybar_network.sh / check_updates*.sh
└── waybar/
    ├── config.jsonc         # waybar principal (portable trixie/forky)
    ├── style.css            # pill + transparente entre pills, sin morado
    ├── themes/
    │   ├── ash-dark.css     # bg #15171e bg-alt #232530 fg #c8c9d1 ...
    │   ├── ash-light.css
    │   ├── nebula.css
    │   └── tokyonight.css
    └── scripts/
        └── waybar-theme.sh  # inyecta @define-color en style.css
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
sudo ./install.sh   # log en ./install.log
sudo reboot
```

El instalador:

1. **Repos** → `main contrib non-free non-free-firmware` + backports
2. **Drivers** → microcode + `nvidia`/`amd`/`intel` + firmware
3. **Base** → `wget curl bc jq`, `network-manager`, `gvfs gvfs-backends gvfs-fuse gvfs-daemons udisks2 udiskie`, **`thunar thunar-archive-plugin thunar-volman xarchiver tumbler ffmpegthumbnailer`**, **`imv swayimg mpv`**, `pipewire wireplumber pavucontrol`, `bluez blueman`, `swaync gnome-calendar`, `wl-clipboard cliphist brightnessctl playerctl`, `foot fuzzel swaybg grim slurp swappy wf-recorder`, **`xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs`**, **`nwg-look`**, `fonts-jetbrains-mono`, `waybar`, `gnome-keyring seahorse polkitd`
   > Tras instalar `thunar` ejecuta automáticamente:
   > ```bash
   > LANG=es_ES.UTF-8 xdg-user-dirs-update --force
   > thunar -q
   > ```
   > para forzar `~/Imágenes`, `~/Documentos` etc. en español. `swayimg` es opcional en `trixie` (fallback a `imv` si no está).
4. **Hyprland stack** → `hyprland hyprlock hypridle hyprpolkitagent` + **`hyprland-guiutils`** + `greetd tuigreet` (desde `trixie-backports` si es trixie, nativo si es forky) + `xdg-desktop-portal-hyprland`
5. **Fuentes** → `Meslo Nerd Font` + `SymbolsOnly` en `~/.local/share/fonts`
6. **Greetd** → `tuigreet --time --remember --cmd start-hyprland` (con vars NVIDIA si `GPU_TYPE=nvidia`)
7. **Dots** → copia `hyprland.conf`, `waybar/*`, `swaync/*`, `foot.ini`/`fuzzel.ini` a `~/.config` y sanitiza `/home/...` → `$USER_HOME`
8. **PAM + Portales** → `pam_gnome_keyring`, `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`
9. **Servicios** → `systemctl enable greetd bluetooth`, `mask getty@tty1` si greetd activo

> Post-instalación: `hyprland --verify-config` y `waybar -l debug` deben dar `config ok` / `Bar configured 1280x30`.

---

## 🖥️ Uso

- **SUPER + Return** → `gnome-terminal` | **SUPER + D** → `fuzzel` | **SUPER + X** → `thunar`
- **SUPER + SHIFT + B** → `pkill waybar; waybar & foot_sync.sh; waybar-theme.sh` (recarga barra + colores)
- **Workspaces** → `SUPER + 1..0` / `SHIFT + 1..0` mover, `SUPER + scroll` navegar, `SUPER + S` scratchpad
- **Brillo/Volumen** → `XF86MonBrightnessUp/Down` (`brightnessctl -e4 -n2 -d intel_backlight set 5%+`), `XF86AudioRaise/LowerVolume` (`wpctl` 2%), scroll sobre `#backlight` / `#pulseaudio`
- **Capturas** → `Print` área/slurp, `ALT+Print` ventana activa (`hyprctl activewindow` + `jq`), `SUPER+Print` monitor, `SHIFT+Print`/`CTRL+Print` `wf-recorder`
- **Power** → `SUPER + L` / drawer `⏻` → `confirm_power.sh` + `group/power`

### Temas

```bash
~/.config/waybar/scripts/waybar-theme.sh nebula   # ash-dark | ash-light | nebula | tokyonight
~/.config/hypr/foot_sync.sh                       # sincroniza foot + fuzzel con el tema
# Tip Wayland: usa nwg-look en vez de lxappearance para GTK sin romper Wayland
nwg-look
```

`waybar-theme.sh` detecta tema actual por `@define-color bg` y hace `SIGUSR2` a `waybar`.

---

## 🔧 Portabilidad

- **Monitores** → ejemplo `DP-3 1920x1080 0x0` + `eDP-1 2560x1600 320x1080 2` + fallback `monitor=,preferred,auto,1`. Edita con `hyprctl monitors`.
- **Waybar** → `output: ["*"]`, `layer: top`, `height: 30`, `interval:1` para todos los relojes.
- **Red/RTC** → `waybar_network.sh` y `check_updates.sh` usan `xdg-user-dir PICTURES` y `return-type: json`.
- **Hardcode sanitizado** → `install.sh:7` hace `sed s|/home/[^/]+|$USER_HOME|g` en dots.
- **Debian trixie/forky** → detección `VERSION_CODENAME` + `ID=debian`, backports condicional.

---

## 🩹 Solución de problemas

**`layerrule = blur, waybar` → `invalid field blur: missing a value` (Hyprland 0.53+)**
> Sintaxis vieja (`layerrule = blur, waybar` / `blurls`) fue reemplazada por bloque. Este repo ya usa:
> ```hypr
> layerrule {
>     name = waybar-blur
>     blur = false
>     ignore_alpha = 0.0
>     match:namespace = waybar
> }
> ```
> Pon `blur = true` si quieres blur. `hyprland 0.55` también soporta `layerrule = blur on, match:namespace waybar`.

**Waybar reloj `invalid arg-id` / `box vacío`**
> Waybar 0.12 usa `fmt` y `"{:%H:%M}  {:%d/%m}"` falla con 2 args. Usa `"{0:%H:%M}  {0:%d/%m}"` (ya en `config.jsonc:35`).

**`battery: argument not found`**
> `"{status}"` no existe en 0.12. Usa `"tooltip-format": "Batería: {capacity}%"` (ya corregido).

**Brillo scroll `Permission denied`**
> `brightnessctl` necesita `video`. El instalador añade a `video/render/input` pero `/sys/class/backlight/.../brightness` es `root:root`. Aplica:
> ```bash
> echo 'SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"' | sudo tee /etc/udev/rules.d/90-backlight.rules
> sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=backlight --action=add
> sudo chgrp video /sys/class/backlight/intel_backlight/brightness; sudo chmod g+w "$_"
> ```

**Hora en UTC (paralelo cero) en vez de GMT-3**
> Sistema ya viene `America/Argentina/Buenos_Aires` (`timedatectl`). Waybar usa:
> ```json
> "locale": "es_AR.UTF-8",
> "timezone": "", // local → automático
> ```
> Si viajas: `sudo timedatectl set-timezone America/Montevideo` y `waybar` sigue. Para UTC al hacer scroll: `"timezones": ["", "Etc/UTC"]`.

**Workspaces sin color**
> Ahora `active/visible` es gris `rgba(200,201,209,0.15)` (antes morado `@purple`). Si lo quieres sólido: `background: @purple; color: @bg;` en `style.css:94`.

---

## 📜 Licencia

Dotfiles bajo MIT. Hyprland BSD-3. Waybar MIT.

## 🙏 Créditos

- [Hyprland](https://hypr.land) vaxerski & contributors
- [Waybar](https://github.com/Alexays/Waybar)
- Fuentes [Nerd Fonts](https://www.nerdfonts.com) (Meslo, SymbolsOnly)
- Wallpaper `wallpaper.jpg` incluido

---

> **Tip:** `SUPER + SHIFT + B` recarga Waybar + `foot_sync.sh` + tema. Para logs: `cat ~/hypr/install.log`, `waybar -l debug`, `hyprland --verify-config`, `journalctl --user -u waybar`.
