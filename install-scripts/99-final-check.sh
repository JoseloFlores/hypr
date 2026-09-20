#!/bin/bash
# 99-final-check.sh — Verificación post-instalación (equivalente a 03-Final-Check.sh)
# No instala nada, solo reporta. Siempre exit 0 salvo error grave de uso.
set -u
set -o pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "99-final-check" || true

echo ""
echo "--- FINAL CHECK ---"
echo "Sistema: Debian ${OS_CODENAME:-?} | Usuario: ${REAL_USER:-?}"
missing=()
bins_missing=()

check_pkg() {
    if pkg_installed "$1"; then
        echo "[OK] $1: $(dpkg-query -W -f='${Version}' "$1" 2>/dev/null)"
    else
        echo "[FALTA] $1 no instalado"
        missing+=("$1")
    fi
}

for p in waybar hyprland tuigreet xdg-desktop-portal-hyprland greetd foot fuzzel sway-notification-center network-manager brightnessctl wl-clipboard; do
    check_pkg "$p"
done

for b in Hyprland waybar tuigreet foot fuzzel swaync hyprlock hypridle nmcli brightnessctl; do
    if command -v "$b" >/dev/null 2>&1; then
        echo "[OK] bin $b: $(command -v "$b")"
    else
        echo "[FALTA] bin $b no en PATH"
        bins_missing+=("$b")
    fi
done

# QuickShell (informativo: no bloquea el GREAT!, cubre INSTALL_QUICKSHELL=OFF)
if [ "${INSTALL_QUICKSHELL:-ON}" = "OFF" ]; then
    echo "[INFO] QuickShell omitido por preset (INSTALL_QUICKSHELL=OFF)"
else
    for b in quickshell wlogout playerctl grim slurp wf-recorder powerprofilesctl; do
        if command -v "$b" >/dev/null 2>&1; then
            echo "[OK] qs bin $b: $(command -v "$b")"
        else
            echo "[FALTA] qs bin $b no en PATH (revisa 30-base/71-quickshell)"
        fi
    done
    if [ -d "${USER_HOME:-$HOME}/quickshell/.git" ]; then
        echo "[OK] fork quickshell clonado en ${USER_HOME:-$HOME}/quickshell"
    else
        echo "[FALTA] ~/quickshell no clonado (71-quickshell.sh lo clona del fork)"
    fi
fi

echo "Greetd: $(systemctl is-enabled greetd 2>&1 || echo 'no habilitado')"
echo "auto-timezone.timer (user $REAL_USER): $(sudo -u "$REAL_USER" env HOME="$USER_HOME" systemctl --user is-enabled auto-timezone.timer 2>&1 || echo 'no habilitado/sin sesión')"

if command -v hyprland >/dev/null 2>&1 || command -v Hyprland >/dev/null 2>&1; then
    echo "-> hyprland --verify-config:"
    (hyprland --verify-config 2>&1 || Hyprland --verify-config 2>&1 || true) | tail -n 5 | tee -a "$LOG"
fi

if [ ${#missing[@]} -eq 0 ] && [ ${#bins_missing[@]} -eq 0 ]; then
    echo "${OK} GREAT! Paquetes esenciales instalados." | tee -a "$LOG"
else
    echo "${WARN} Faltantes deb: ${missing[*]:-ninguno} | bins: ${bins_missing[*]:-ninguno}" | tee -a "$LOG"
    printf "%s\n" "${missing[@]}" "${bins_missing[@]}" >> "$LOG"
fi

if pkg_installed hyprland && pkg_installed waybar; then
    echo "¡INSTALACIÓN COMPLETADA!" | tee -a "$LOG"
    if [ "${GPU_TYPE:-generic}" = "nvidia" ]; then
        echo "AVISO NVIDIA: añade 'nvidia-drm.modeset=1' a GRUB_CMDLINE_LINUX en /etc/default/grub y ejecuta: update-grub" | tee -a "$LOG"
    fi
else
    echo "¡INSTALACIÓN INCOMPLETA! Revisa logs en $LOG_DIR" | tee -a "$LOG"
    exit 1
fi
