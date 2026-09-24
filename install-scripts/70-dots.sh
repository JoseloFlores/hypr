#!/bin/bash
# 70-dots.sh — Despliegue de dotfiles a ~/.config (paso 7/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "70-dots"

log "7/10 Desplegando configuraciones en $USER_HOME/.config..."

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] cp hyprland.conf hypridle.conf foot.ini noctalia/{*.toml,templates,hooks} noctalia/plugins-apply.sh+plugins/*.patch systemd/user/* wlogout/layout+icons scripts a $USER_HOME/.config + wallpapers download (\$WALLPAPER_URL -> \$WALLPAPER_DIR)" | tee -a "$LOG"
    exit 0
fi

DOTS_CONF="$USER_HOME/.config"
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p \
    "$DOTS_CONF/hypr" "$DOTS_CONF/noctalia" "$DOTS_CONF/foot" \
    "$DOTS_CONF/systemd/user" "$DOTS_CONF/wlogout"

for src in hyprland.conf hypridle.conf; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
    fi
done
# Semilla local opcional (no versionada): si existe en el repo se usa como fallback.
# El caso normal es descarga vía WALLPAPER_URL (ver abajo).
if [ -f "$SCRIPT_DIR/wallpaper.jpg" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/wallpaper.jpg" "$DOTS_CONF/hypr/"
    log "-> semilla wallpaper.jpg copiada a $DOTS_CONF/hypr/ (legado, no versionar)"
fi

for src in confirm_power.sh auto_timezone.sh screen_recorder.sh; do
    if [ -f "$SCRIPT_DIR/$src" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/$src" "$DOTS_CONF/hypr/"
        chmod +x "$DOTS_CONF/hypr/$src" 2>/dev/null || true
    fi
done
# plugins-apply.sh vive en noctalia/ del repo (no en install-scripts/).
if [ -f "$SCRIPT_DIR/../noctalia/plugins-apply.sh" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/../noctalia/plugins-apply.sh" "$DOTS_CONF/hypr/noctalia-plugins-apply.sh"
    chmod +x "$DOTS_CONF/hypr/noctalia-plugins-apply.sh" 2>/dev/null || true
fi
# Parche wf-recorder del plugin region-recorder (lo aplica noctalia-plugins-apply.sh;
# se versiona aquí porque el caché materialized de Noctalia se regenera en cada install).
if [ -d "$SCRIPT_DIR/../noctalia/plugins" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$DOTS_CONF/hypr/noctalia-plugins"
    for pf in "$SCRIPT_DIR"/../noctalia/plugins/*.patch; do
        [ -f "$pf" ] || continue
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$pf" "$DOTS_CONF/hypr/noctalia-plugins/"
    done
    log "-> noctalia-plugins-apply.sh + parches en $DOTS_CONF/hypr/"
fi

# wlogout layout (style.css lo genera el template Noctalia al iniciar sesión;
# wlogout/style.css del repo es legado y ya no se versiona ni se copia).
if [ -d "$SCRIPT_DIR/wlogout" ]; then
    if [ -f "$SCRIPT_DIR/wlogout/layout" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/wlogout/layout" "$DOTS_CONF/wlogout/"
    fi
    # Portable: el template trae una ruta absoluta del autor; se reescribe al
    # HOME real (el template Noctalia también usa __HOME__; esto cubre el layout).
    if [ -f "$DOTS_CONF/wlogout/style.css" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" \
            sed -i -E "s#url\(\"/home/[^/\"]+#url(\"$USER_HOME#g" "$DOTS_CONF/wlogout/style.css" || true
    fi
    log "-> wlogout desplegado en $DOTS_CONF/wlogout/"
    # Iconos (el template solo genera style.css; los png van en repo)
    if [ -d "$SCRIPT_DIR/wlogout/icons" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$USER_HOME/.local/share/wlogout/icons"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/wlogout/icons/"*.png "$USER_HOME/.local/share/wlogout/icons/"
    fi
fi

# Neovim (sin pisar config existente; matugen.lua lo genera el template Noctalia)
if [ -d "$SCRIPT_DIR/nvim" ]; then
    if [ ! -e "$USER_HOME/.config/nvim" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$USER_HOME/.config/nvim/lua/plugins"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/nvim/init.lua" "$USER_HOME/.config/nvim/"
        [ -f "$SCRIPT_DIR/nvim/lazy-lock.json" ] && sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/nvim/lazy-lock.json" "$USER_HOME/.config/nvim/"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/nvim/lua/plugins/"*.lua "$USER_HOME/.config/nvim/lua/plugins/"
        log "-> nvim desplegado en $USER_HOME/.config/nvim/ (plugins los baja lazy.nvim)"
    else
        log "-> nvim existente, no se pisa (el template aporta matugen.lua)"
    fi
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
            for tf in "$SCRIPT_DIR/noctalia/$sub/"*; do
                [ -f "$tf" ] || continue
                sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$tf" "$DOTS_CONF/noctalia/$sub/"
            done
        fi
    done
    sudo -u "$REAL_USER" env HOME="$USER_HOME" \
        sed -i "s#__HOME__#$USER_HOME#g" "$DOTS_CONF"/noctalia/*.toml "$DOTS_CONF"/noctalia/templates/* "$DOTS_CONF"/noctalia/hooks/* 2>/dev/null || true
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

if [ -f "$SCRIPT_DIR/foot.ini" ] && [ ! -f "$DOTS_CONF/foot/foot.ini" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$SCRIPT_DIR/foot.ini" "$DOTS_CONF/foot/foot.ini"
    log "-> foot.ini desplegado en $DOTS_CONF/foot/"
fi

HYPR_CONF="$DOTS_CONF/hypr/hyprland.conf"
if [ "$GPU_TYPE" = "nvidia" ] && [ -f "$HYPR_CONF" ]; then
    sed -i '/^# NVIDIA_ENV_BEGIN/,/^# NVIDIA_ENV_END/{s/^# env =/env =/;}' "$HYPR_CONF"
    log "-> hyprland.conf: variables NVIDIA activadas"
fi

# --- Wallpapers descargables (no versionados) ---
# WALLPAPER_URL: zip o jpg suelto. WALLPAPER_DIR: destino (~/Imágenes/wallpapers/wallpaper).
# Defensa: si WALLPAPER_DIR apunta a /root (HOME de sudo), se re-resuelve al usuario real.
WALLPAPER_DIR="${WALLPAPER_DIR:-$USER_HOME/Imágenes/wallpapers/wallpaper}"
[[ "$WALLPAPER_DIR" == /root/* ]] && WALLPAPER_DIR="$USER_HOME/Imágenes/wallpapers/wallpaper"
WALLPAPER_URL="${WALLPAPER_URL:-}"
if [ -n "$WALLPAPER_URL" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$WALLPAPER_DIR"
    log "-> descargando wallpapers: $WALLPAPER_URL -> $WALLPAPER_DIR"
    if [[ "$WALLPAPER_URL" == *.zip ]]; then
        _tmpzip="/tmp/wallpapers-$(date +%s).zip"
        if sudo -u "$REAL_USER" env HOME="$USER_HOME" wget -q --show-progress --tries=5 --waitretry=3 --timeout=20 -O "$_tmpzip" "$WALLPAPER_URL"; then
            sudo -u "$REAL_USER" env HOME="$USER_HOME" unzip -o -q "$_tmpzip" -d "$WALLPAPER_DIR"
            rm -f "$_tmpzip"
        else
            log_warn "no se pudo descargar WALLPAPER_URL (zip). Revisa la URL."
        fi
    else
        _fname="$(basename "$WALLPAPER_URL")"
        [ -z "$_fname" ] && _fname="wallpaper.jpg"
        sudo -u "$REAL_USER" env HOME="$USER_HOME" wget -q --show-progress --tries=5 --waitretry=3 --timeout=20 -O "$WALLPAPER_DIR/$_fname" "$WALLPAPER_URL" \
            || log_warn "no se pudo descargar WALLPAPER_URL. Revisa la URL."
    fi
    # Semilla para hyprlock si aún no existe (el hook wallpaper_changed lo mantiene luego).
    if [ ! -f "$DOTS_CONF/hypr/wallpaper.jpg" ]; then
        _first="$(sudo -u "$REAL_USER" env HOME="$USER_HOME" bash -c "ls -1 \"$WALLPAPER_DIR\"/*.{jpg,jpeg,png,webp} 2>/dev/null | head -n1" || true)"
        if [ -n "$_first" ] && [ -f "$_first" ]; then
            sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$_first" "$DOTS_CONF/hypr/wallpaper.jpg"
            log "-> semilla hyprlock desde pack descargado"
        fi
    fi
    chown -R "$REAL_USER":"$REAL_USER" "$WALLPAPER_DIR" 2>/dev/null || true
else
    log "-> WALLPAPER_URL vacío: se omite descarga (crea $WALLPAPER_DIR o define URL en preset)"
    sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$WALLPAPER_DIR" || true
fi

chown -R "$REAL_USER":"$REAL_USER" "$DOTS_CONF"
find "$DOTS_CONF" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
log_ok "Dots OK (colores los aplica Noctalia al iniciar sesión: templates-apply)"
