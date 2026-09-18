#!/bin/bash
# 70-dots.sh — Despliegue de dotfiles a ~/.config (paso 7/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "70-dots"

log "7/10 Desplegando configuraciones en $USER_HOME/.config..."

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] cp hyprland.conf waybar/* swaync/* foot.ini fuzzel.ini systemd/user/* wlogout/* launchers/set-wallpaper a $USER_HOME/.config + foot_sync.sh" | tee -a "$LOG"
    exit 0
fi

DOTS_CONF="$USER_HOME/.config"
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p \
    "$DOTS_CONF/hypr" "$DOTS_CONF/waybar/themes" "$DOTS_CONF/waybar/scripts" \
    "$DOTS_CONF/swaync" "$DOTS_CONF/foot" "$DOTS_CONF/fuzzel" \
    "$DOTS_CONF/systemd/user" "$DOTS_CONF/wlogout" "$DOTS_CONF/quickshell"

for src in hyprland.conf hyprlock.conf hypridle.conf wallpaper.jpg; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
    fi
done

for src in waybar_network.sh wifi_click.sh check_updates.sh check_updates_count.sh confirm_power.sh foot_sync.sh power_menu.sh waybar-launcher.sh auto_timezone.sh screen_recorder.sh quickshell-launcher.sh volver-waybar.sh probar-quickshell.sh set-wallpaper.sh; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
        chmod +x "$DOTS_CONF/hypr/$src" 2>/dev/null || true
    fi
done

# wlogout (layout + estilo base; set-wallpaper.sh lo regenera al tono de la paleta)
if [ -d "$SCRIPT_DIR/wlogout" ]; then
    for wl in layout style.css; do
        if [ -f "$SCRIPT_DIR/wlogout/$wl" ]; then
            sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/wlogout/$wl" "$DOTS_CONF/wlogout/"
        fi
    done
    log "-> wlogout desplegado en $DOTS_CONF/wlogout/"
fi

# Guía rápida quickshell (solo docs)
if [ -f "$SCRIPT_DIR/QUICKSHELL_COMANDOS.md" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/QUICKSHELL_COMANDOS.md" "$DOTS_CONF/hypr/"
fi

if [ -d "$SCRIPT_DIR/waybar" ]; then
    if [ -f "$SCRIPT_DIR/waybar/config.jsonc" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/waybar/config.jsonc" "$DOTS_CONF/waybar/config.jsonc"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/waybar/config.jsonc" "$DOTS_CONF/waybar/config"
    fi
    if [ -f "$SCRIPT_DIR/waybar/style.css" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/waybar/style.css" "$DOTS_CONF/waybar/style.css"
    fi
    for th in "$SCRIPT_DIR/waybar/themes"/*.css; do
        [ -f "$th" ] || continue
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$th" "$DOTS_CONF/waybar/themes/"
    done
    for sh in "$SCRIPT_DIR/waybar/scripts"/*.sh; do
        [ -f "$sh" ] || continue
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$sh" "$DOTS_CONF/waybar/scripts/"
        chmod +x "$DOTS_CONF/waybar/scripts/$(basename "$sh")"
    done
else
    log_warn "No se encontró $SCRIPT_DIR/waybar, se omite despliegue Waybar"
fi

if [ -d "$SCRIPT_DIR/systemd/user" ]; then
    for u in "$SCRIPT_DIR/systemd/user"/*; do
        [ -f "$u" ] || continue
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$u" "$DOTS_CONF/systemd/user/"
    done
    if sudo -u "$REAL_USER" env HOME="$USER_HOME" systemctl --user enable auto-timezone.timer 2>/dev/null; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" systemctl --user start auto-timezone.timer 2>/dev/null || true
        log "-> auto-timezone.timer habilitado (zona horaria automática cada 30 min)"
    else
        log_warn "auto-timezone.timer no se pudo habilitar ahora (sin sesión de usuario activa)."
        echo "       En el primer inicio con Hyprland ejecuta: systemctl --user enable --now auto-timezone.timer"
    fi
fi

for app in foot fuzzel; do
    if [ -f "$SCRIPT_DIR/$app.ini" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$app.ini" "$DOTS_CONF/$app/$app.ini"
        log "-> $app.ini desplegado en $DOTS_CONF/$app/"
    fi
done

if [ -f "$SCRIPT_DIR/swaync_config.json" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/swaync_config.json" "$DOTS_CONF/swaync/config.json"
fi
if [ -f "$SCRIPT_DIR/swaync_style.css" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/swaync_style.css" "$DOTS_CONF/swaync/style.css"
fi

HYPR_CONF="$DOTS_CONF/hypr/hyprland.conf"
if [ "$GPU_TYPE" = "nvidia" ] && [ -f "$HYPR_CONF" ]; then
    sed -i '/^# NVIDIA_ENV_BEGIN/,/^# NVIDIA_ENV_END/{s/^# env =/env =/;}' "$HYPR_CONF"
    log "-> hyprland.conf: variables NVIDIA activadas"
fi

chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

if [ -f "$DOTS_CONF/hypr/foot_sync.sh" ]; then
    log "-> Sincronizando paleta inicial para Foot y Fuzzel..."
    sudo -u "$REAL_USER" env HOME="$USER_HOME" bash "$DOTS_CONF/hypr/foot_sync.sh" || true
fi
log_ok "Dots OK"
