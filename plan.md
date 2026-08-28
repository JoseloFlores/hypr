# Plan: Hyprland + GNOME comforts en Debian 13 (trixie) — sin Mutter

## Objetivo
Un solo `sudo ./install.sh` lleva Debian 13 netinst minimal (sin GUI) → sistema funcional Hyprland con flexibilidad Hyprland + comodidades GNOME, evitando reglas estrictas de Mutter (`blur`/`rounding`/`opacity` en `hyprland.conf:130`).

## Decisiones del usuario (2026-08-27)
1. Solo `nautilus` (no `thunar`)
2. Barra `eww` + `solar-dashboard` (no waybar)
3. Notificaciones `sway-notification-center` (paquete `sway-notification-center`, bins `swaync`/`swaync-client`) + `gnome-calendar`
4. Polkit `hyprpolkitagent` (no `policykit-1-gnome` deprecado)
5. Navegador `firefox-esr` (chrome manual)
6. Repos extra (`brave/chrome/spotify/tailscale/vscode`) no tocar
7. `zsh` solo
8. Fonts `fonts-jetbrains-mono` (apt) + `Meslo Nerd` + `Nerd Symbols` (descarga)
9. `bluetooth` enable
10. PAM `gnome-keyring` auto-unlock
11. Repo plano (se mantiene)

## Stack “GNOME sin GNOME Shell”
- Automontaje: `gvfs gvfs-backends gvfs-fuse gvfs-daemons udisks2 udiskie` + `nautilus sushi file-roller`
- Audio por app: `pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol`
- BT: `bluez blueman` + `blueman-applet &` + `systemctl enable bluetooth`
- Notificaciones: `sway-notification-center gnome-calendar`, widgets `[title,dnd,calendar,notifications]`, `swaync &`, binds `swaync-client -t/-R`
- Seguridad: `hyprpolkitagent` (`systemctl --user start hyprpolkitagent`), `gnome-keyring libpam-gnome-keyring seahorse` + `gnome-keyring-daemon --start --components=pkcs11,secrets,ssh` + PAM `pam_gnome_keyring.so`
- Portapapeles: `wl-clipboard cliphist` + `wl-paste --watch cliphist store &`
- Portals: `xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland` (backports)

## Cambios `hyprland.conf`
- `$browser = firefox-esr` (antes `google-chrome-stable`)
- `exec-once` añade: `gnome-keyring-daemon`, `udiskie -t &`, `blueman-applet &`, `swaync &`, `wl-paste ...`, mantiene `hyprpolkitagent`/`hypridle`
- `windowrule` ya contempla `gnome-calendar`, `blueman-manager`, `pavucontrol`

## `install.sh` — 10 fases (ver `install.sh:1`)
0 validaciones (EUID,SUDO_USER,ping) → 1 repos backports idempotente → 2 hw (microcode/GPU/firmware) → 3 base GNOME comforts → 4 Hyprland backports → 5 fonts → 6 eww cargo → 7 greetd/tuigreet (`start-hyprland` + env nvidia) → 8 dots (plano→`~/.config/{hypr,swaync,eww}` + `swaync_config.json/style.css`) → 9 permisos/PAM/portals → 10 servicios (greetd/bluetooth/graphical.target)

## Correcciones aplicadas
- `install.sh:27` backports ahora incluye `main contrib non-free non-free-firmware` completo
- `install.sh:76` quita `thunar`, añade `udisks2/pipewire-*/bluez/sway-notification-center/seahorse/polkitd/fonts-*`
- `install.sh:93` descarga Meslo+Symbols con helper `install_nerd_font` y URL correcta (antes `[https://...](...)` roto)
- `eww_start.sh:1`/`eww_restart.sh:1` usan `/usr/local/bin/eww` con fallback, `GDK_BACKEND=wayland`, sync `foot_sync.sh`
- Nuevos `swaync_config.json`/`swaync_style.css` planos para deploy a `~/.config/swaync/`
- `install.sh:185` PAM crea `/etc/pam.d/greetd` con `pam_gnome_keyring.so` y hace `pam-auth-update --enable gnome-keyring`

## Notas instalación limpia
- No instalar `gnome-shell/mutter/gdm` a propósito.
- `eww` compila 5-10 min; cache en `/tmp/eww_build`.
- `fc-cache -fv` tras fonts.
- `nvidia-drm.modeset=1` manual si nvidia.
- Log en `install.log` junto al repo.

## Futuro opcional
- Migrar repo plano → `configs/`/`scripts/`/`assets/` (más legible, `cp -r configs/* ~/.config/`).
- Añadir `shellcheck` CI.
