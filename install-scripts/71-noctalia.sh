#!/bin/bash
# 71-noctalia.sh — Shell Noctalia v5 (barra, launcher, notificaciones, control-center)
# Requiere: 10-repos, 70-dots (hyprland.conf con exec-once = noctalia)
# Noctalia no está en Debian: se instala desde su repo APT (pkg.noctalia.dev).
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "71-noctalia"

if [ "${INSTALL_NOCTALIA:-ON}" = "OFF" ]; then
    log "Noctalia desactivado por preset (INSTALL_NOCTALIA=OFF), se omite."
    exit 0
fi

log "7b/10 Instalando Noctalia v5 + deps runtime..."

case "${OS_CODENAME:-trixie}" in
    trixie) NOCTALIA_SUITE="noctalia-trixie" ;;
    # Debian 14 forky (testing) no tiene suite propia (solo trixie/unstable en
    # pkg.noctalia.dev 2026-09). Forky va con unstable: sigue a testing/sid.
    forky|sid|unstable) NOCTALIA_SUITE="noctalia-unstable" ;;
    *)
        log_error "OS '$OS_CODENAME' sin suite Noctalia (solo trixie/forky). Abortando."
        exit 1
        ;;
esac
log "-> suite Noctalia: $NOCTALIA_SUITE (Debian $OS_CODENAME)"

run_bash "keyring noctalia" \
    bash -c 'wget -q https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb -O /tmp/nickh-archive-keyring.deb && dpkg -i /tmp/nickh-archive-keyring.deb'
run_bash "sources noctalia" \
    bash -c "wget -q -O /etc/apt/sources.list.d/$NOCTALIA_SUITE.sources https://pkg.noctalia.dev/deb/$NOCTALIA_SUITE.sources"
apt_update_resilient

apt_install_resilient noctalia
# Runtime que los widgets de Noctalia esperan (si ya están, apt no hace nada)
apt_install_resilient upower power-profiles-daemon brightnessctl cliphist wl-clipboard

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] deploy noctalia/*.toml a $USER_HOME/.config/noctalia + noctalia --version + config validate" | tee -a "$LOG"
    exit 0
fi

# --- ~/.config/noctalia (sin pisar config del usuario si ya existe) ---
if [ -d "$SCRIPT_DIR/noctalia" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$USER_HOME/.config/noctalia"
    for f in "$SCRIPT_DIR"/noctalia/*.toml; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        if [ ! -f "$USER_HOME/.config/noctalia/$base" ]; then
            sudo -u "$REAL_USER" env HOME="$USER_HOME" cp -f "$f" "$USER_HOME/.config/noctalia/"
        fi
    done
    chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config/noctalia" 2>/dev/null || true
fi

# --- ~/Pictures/Capturas + symlink ~/Imágenes/Capturas (destino de grim/wf-recorder) ---
sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$USER_HOME/Pictures/Capturas"
if [ ! -e "$USER_HOME/Imágenes/Capturas" ]; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" ln -s "$USER_HOME/Pictures/Capturas" "$USER_HOME/Imágenes/Capturas" \
        && log "-> symlink Imágenes/Capturas -> Pictures/Capturas" || true
fi
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/Pictures/Capturas" 2>/dev/null || true

# --- GTK oscuro base (los templates gtk3/gtk4 de Noctalia ponen los colores) ---
# adw-gtk3 no está en repos Debian: Adwaita-dark + import noctalia.css es suficiente.
for gver in 3.0 4.0; do
    gdir="$USER_HOME/.config/gtk-$gver"
    gini="$gdir/settings.ini"
    sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$gdir"
    if [ ! -f "$gini" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" cat > "$gini" <<EOF
[Settings]
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF
    else
        sudo -u "$REAL_USER" env HOME="$USER_HOME" \
            sed -i -E 's/^gtk-theme-name=.*/gtk-theme-name=Adwaita-dark/; s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=1/' "$gini" || true
    fi
done
log "-> GTK en Adwaita-dark + prefer-dark (colores via templates Noctalia)"

if command -v noctalia >/dev/null 2>&1; then
    log "-> $(noctalia --version 2>&1 | head -n1)"
    if sudo -u "$REAL_USER" env HOME="$USER_HOME" noctalia config validate >/dev/null 2>&1; then
        log_ok "Noctalia OK (arranca con exec-once = noctalia en hyprland.conf)"
    else
        log_warn "Noctalia instalado pero 'noctalia config validate' reporta avisos; revisa ~/.config/noctalia/"
    fi
else
    log_warn "Binario 'noctalia' no encontrado tras instalar. Revisa el repo APT."
fi
