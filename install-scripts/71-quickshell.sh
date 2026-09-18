#!/bin/bash
# 71-quickshell.sh — Shell QuickShell (barra) + menú wlogout + paleta pywal
# Requiere: 10-repos (backports para quickshell), 70-dots (hyprland.conf, wallpaper.jpg)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "71-quickshell"

if [ "${INSTALL_QUICKSHELL:-ON}" = "OFF" ]; then
    log "QuickShell desactivado por preset (INSTALL_QUICKSHELL=OFF), se omite."
    exit 0
fi

log "7b/10 Instalando QuickShell + wlogout + pywal..."

# --- Paquetes apt (quickshell vive en trixie-backports) ---
apt_hypr_stack quickshell || log_warn "quickshell no se pudo instalar desde backports"
apt_install_resilient wlogout imagemagick python3-pip git upower power-profiles-daemon

# --- pywal + colorz (backend sin ImageMagick) a nivel usuario ---
run_bash "pip pywal+colorz" sudo -u "$REAL_USER" env HOME="$USER_HOME" \
    pip install --user --break-system-packages pywal colorz 2>/dev/null \
    || sudo -u "$REAL_USER" env HOME="$USER_HOME" pip install --user pywal colorz || true

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] git clone quickshell a $USER_HOME/quickshell + apply patches/quickshell-local.patch + set-wallpaper.sh + quickshell --version" | tee -a "$LOG"
    exit 0
fi

# --- Config quickshell: clonar + aplicar ajustes locales versionados ---
QS_DIR="$USER_HOME/quickshell"
if [ ! -d "$QS_DIR/.git" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" \
        git clone https://github.com/tripathiji1312/quickshell.git "$QS_DIR" || {
        log_warn "No se pudo clonar quickshell (¿sin red?). Se omite despliegue de config."
    }
fi
PATCH="$SCRIPT_DIR/patches/quickshell-local.patch"
if [ -d "$QS_DIR/.git" ] && [ -f "$PATCH" ]; then
    if sudo -u "$REAL_USER" env HOME="$USER_HOME" git -C "$QS_DIR" apply --check "$PATCH" 2>/dev/null; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" git -C "$QS_DIR" apply "$PATCH" \
            && log "-> parche quickshell-local aplicado" \
            || log_warn "El parche quickshell no aplicó limpio; revisa $QS_DIR"
    else
        log "-> parche quickshell ya aplicado o no corresponde, se omite"
    fi
fi

# --- ~/.config/quickshell (layer rules + shell.json por defecto, sin pisar usuario) ---
if [ -d "$QS_DIR" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$USER_HOME/.config/quickshell"
    if [ -f "$QS_DIR/hyprland-layer-config.conf" ] && [ ! -f "$USER_HOME/.config/quickshell/hyprland-layer-config.conf" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$QS_DIR/hyprland-layer-config.conf" "$USER_HOME/.config/quickshell/"
    fi
    if [ -f "$QS_DIR/shell.json" ] && [ ! -f "$USER_HOME/.config/quickshell/shell.json" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$QS_DIR/shell.json" "$USER_HOME/.config/quickshell/"
    fi
    chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config/quickshell" "$QS_DIR" 2>/dev/null || true
fi

# --- wlogout funcional desde el primer arranque ---
if [ -f "$USER_HOME/.config/hypr/set-wallpaper.sh" ] && [ -f "$USER_HOME/.config/hypr/wallpaper.jpg" ]; then
    log "-> Generando paleta inicial + estilo wlogout..."
    sudo -u "$REAL_USER" env HOME="$USER_HOME" PATH="$USER_HOME/.local/bin:$PATH" \
        bash "$USER_HOME/.config/hypr/set-wallpaper.sh" "$USER_HOME/.config/hypr/wallpaper.jpg" || true
fi

if command -v quickshell >/dev/null 2>&1; then
    log "-> $(quickshell --version 2>&1 | head -n1)"
    log_ok "QuickShell OK (arranca con quickshell-launcher.sh; rollback: volver-waybar.sh)"
else
    log_warn "Binario 'quickshell' no encontrado tras instalar. Revisa backports."
fi
