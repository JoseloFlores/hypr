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

# Candidatas por OS. Forky no tiene suite propia (solo trixie/unstable en
# pkg.noctalia.dev 2026-09): se prueba trixie primero (libwebp 1.5, la que trae
# forky-testing) y luego unstable (libwebp 1.6 de sid). Ver logs forky 14.
case "${OS_CODENAME:-trixie}" in
    trixie) NOCTALIA_CANDIDATES="noctalia-trixie" ;;
    forky) NOCTALIA_CANDIDATES="noctalia-trixie noctalia-unstable" ;;
    sid|unstable) NOCTALIA_CANDIDATES="noctalia-unstable" ;;
    *)
        log_error "OS '$OS_CODENAME' sin suite Noctalia (solo trixie/forky/sid)."
        exit 1
        ;;
esac
log "-> suites candidatas: $NOCTALIA_CANDIDATES (Debian $OS_CODENAME)"

run_bash "keyring noctalia" \
    bash -c 'wget -q https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb -O /tmp/nickh-archive-keyring.deb && dpkg -i /tmp/nickh-archive-keyring.deb'

# Runtime nativo Debian que los widgets esperan (vaya bien o no Noctalia).
apt_install_resilient upower power-profiles-daemon brightnessctl cliphist wl-clipboard || true

if [ "$DRY_RUN" = "1" ]; then
    for _s in $NOCTALIA_CANDIDATES; do
        echo "[DRY-RUN] suite $_s -> /etc/apt/sources.list.d/$_s.sources + apt update + apt install noctalia" | tee -a "$LOG"
    done
    echo "[DRY-RUN] deploy noctalia/*.toml a $USER_HOME/.config/noctalia + noctalia --version + config validate" | tee -a "$LOG"
    exit 0
fi

# --- Intento de instalación por suites candidatas (no bloqueante) ---
for NOCTALIA_SUITE in $NOCTALIA_CANDIDATES; do
    log "-> probando suite $NOCTALIA_SUITE..."
    if ! bash -c "wget -q -O /etc/apt/sources.list.d/$NOCTALIA_SUITE.sources https://pkg.noctalia.dev/deb/$NOCTALIA_SUITE.sources"; then
        log_warn "no se pudo descargar $NOCTALIA_SUITE.sources, siguiente candidata."
        rm -f "/etc/apt/sources.list.d/$NOCTALIA_SUITE.sources"
        continue
    fi
    if ! apt_update_resilient; then
        log_warn "apt update falló con $NOCTALIA_SUITE, siguiente candidata."
        rm -f "/etc/apt/sources.list.d/$NOCTALIA_SUITE.sources"
        continue
    fi
    if apt_install_resilient noctalia; then
        log "-> suite que funcionó: $NOCTALIA_SUITE"
        break
    fi
    log_warn "noctalia no instalable con $NOCTALIA_SUITE (dependencias), siguiente candidata."
    rm -f "/etc/apt/sources.list.d/$NOCTALIA_SUITE.sources"
done

# --- ~/.config/noctalia (sin pisar config del usuario si ya existe) ---
# Se despliega aunque el paquete falle: el reintento posterior solo reinstala el .deb.
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
    rm -f "$LOG_DIR/noctalia-missing.flag" 2>/dev/null || true
    if sudo -u "$REAL_USER" env HOME="$USER_HOME" noctalia config validate >/dev/null 2>&1; then
        log_ok "Noctalia OK (arranca con exec-once = noctalia en hyprland.conf)"
    else
        log_warn "Noctalia instalado pero 'noctalia config validate' reporta avisos; revisa ~/.config/noctalia/"
    fi
    exit 0
fi
# Sin binario tras probar todas las candidatas: NO bloquea el instalador.
# 90-services/95-grub/99-final-check siguen; el reintento es solo este módulo.
touch "$LOG_DIR/noctalia-missing.flag" 2>/dev/null || true
log_warn "Noctalia no instalable en Debian $OS_CODENAME con: $NOCTALIA_CANDIDATES."
log_warn "Hyprland queda usable sin shell Noctalia. Reintenta luego:"
log_warn "  sudo ./install.sh --only 71-noctalia,99-final-check"
exit 0
