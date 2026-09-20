#!/bin/bash
# 70-dots.sh — Despliegue de dotfiles a ~/.config (paso 7/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "70-dots"

log "7/10 Desplegando configuraciones en $USER_HOME/.config..."

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] cp hyprland.conf hypridle.conf foot.ini fuzzel.ini noctalia/{*.toml,templates,hooks} systemd/user/* wlogout/* scripts a $USER_HOME/.config" | tee -a "$LOG"
    exit 0
fi

DOTS_CONF="$USER_HOME/.config"
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p \
    "$DOTS_CONF/hypr" "$DOTS_CONF/noctalia" "$DOTS_CONF/foot" "$DOTS_CONF/fuzzel" \
    "$DOTS_CONF/systemd/user" "$DOTS_CONF/wlogout"

for src in hyprland.conf hypridle.conf wallpaper.jpg; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
    fi
done

for src in confirm_power.sh power_menu.sh auto_timezone.sh screen_recorder.sh; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
        chmod +x "$DOTS_CONF/hypr/$src" 2>/dev/null || true
    fi
done

# wlogout layout (style.css lo genera el template Noctalia al iniciar sesión)
if [ -d "$SCRIPT_DIR/wlogout" ]; then
    for wl in layout style.css; do
        if [ -f "$SCRIPT_DIR/wlogout/$wl" ]; then
            sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/wlogout/$wl" "$DOTS_CONF/wlogout/"
        fi
    done
    # Portable: el template trae una ruta absoluta del autor; se reescribe al
    # HOME real (el template Noctalia también usa __HOME__; esto cubre el layout).
    if [ -f "$DOTS_CONF/wlogout/style.css" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" \
            sed -i -E "s#url\(\"/home/[^/\"]+#url(\"$USER_HOME#g" "$DOTS_CONF/wlogout/style.css" || true
    fi
    log "-> wlogout desplegado en $DOTS_CONF/wlogout/"
fi

# Guía rápida Noctalia (solo docs)
if [ -f "$SCRIPT_DIR/NOCTALIA_COMANDOS.md" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/NOCTALIA_COMANDOS.md" "$DOTS_CONF/hypr/"
fi

# Config Noctalia: *.toml sin pisar los del usuario; templates/ y hooks/ siempre
# (son código del repo; __HOME__ se reescribe al HOME real).
if [ -d "$SCRIPT_DIR/noctalia" ]; then
    for f in "$SCRIPT_DIR"/noctalia/*.toml; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        if [ ! -f "$DOTS_CONF/noctalia/$base" ]; then
            sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$f" "$DOTS_CONF/noctalia/"
        fi
    done
    for sub in templates hooks; do
        if [ -d "$SCRIPT_DIR/noctalia/$sub" ]; then
            sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$DOTS_CONF/noctalia/$sub"
            sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/noctalia/$sub/"* "$DOTS_CONF/noctalia/$sub/"
        fi
    done
    sudo -u "$REAL_USER" env HOME="$USER_HOME" \
        sed -i "s#__HOME__#$USER_HOME#g" "$DOTS_CONF"/noctalia/*.toml "$DOTS_CONF"/noctalia/templates/* 2>/dev/null || true
    log "-> noctalia/*.toml + templates/ + hooks/ desplegado en $DOTS_CONF/noctalia/"
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
    if [ -f "$SCRIPT_DIR/$app.ini" ] && [ ! -f "$DOTS_CONF/$app/$app.ini" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$app.ini" "$DOTS_CONF/$app/$app.ini"
        log "-> $app.ini desplegado en $DOTS_CONF/$app/"
    fi
done

HYPR_CONF="$DOTS_CONF/hypr/hyprland.conf"
if [ "$GPU_TYPE" = "nvidia" ] && [ -f "$HYPR_CONF" ]; then
    sed -i '/^# NVIDIA_ENV_BEGIN/,/^# NVIDIA_ENV_END/{s/^# env =/env =/;}' "$HYPR_CONF"
    log "-> hyprland.conf: variables NVIDIA activadas"
fi

chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
log_ok "Dots OK (colores los aplica Noctalia al iniciar sesión: templates-apply)"
