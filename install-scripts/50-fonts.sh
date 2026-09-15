#!/bin/bash
# 50-fonts.sh — Fuentes Meslo + SymbolsOnly (paso 5/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "50-fonts"

log "5/10 Instalando fuentes (Meslo + Symbols)..."

FONT_DIR="$USER_HOME/.local/share/fonts"
MESLO_DIR="$FONT_DIR/Meslo"
SYMBOLS_DIR="$FONT_DIR/NerdSymbols"

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] descargar Meslo.zip + NerdSymbolsOnly.zip a $FONT_DIR + fc-cache" | tee -a "$LOG"
    exit 0
fi

sudo -u "$REAL_USER" env HOME="$USER_HOME" mkdir -p "$MESLO_DIR" "$SYMBOLS_DIR"

install_nerd_font() {
    local url="$1"
    local dest="$2"
    local tmpzip="/tmp/$(basename "$dest").zip"
    if sudo -u "$REAL_USER" env HOME="$USER_HOME" wget -q --show-progress --tries=5 --waitretry=3 --timeout=15 -O "$tmpzip" "$url"; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" unzip -o -q "$tmpzip" -d "$dest"
        rm -f "$tmpzip"
    fi
}

[ -z "$(ls -A "$MESLO_DIR" 2>/dev/null)" ] && install_nerd_font "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip" "$MESLO_DIR"
[ -z "$(ls -A "$SYMBOLS_DIR" 2>/dev/null)" ] && install_nerd_font "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip" "$SYMBOLS_DIR"

sudo -u "$REAL_USER" env HOME="$USER_HOME" fc-cache -fv "$FONT_DIR" 2>&1 | tail -n 20 || true
fc-cache -fv 2>&1 | tail -n 5 || true
chown -R "$REAL_USER":"$REAL_USER" "$FONT_DIR" || true
log_ok "Fuentes OK"
