#!/bin/bash
# 95-grub.sh — Tema GRUB gráfico desktop-base (paso 10/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "95-grub"

log "10/10 Forzando tema GRUB gráfico de Debian..."
if [ "${INSTALL_GRUB_THEME:-ON}" = "OFF" ]; then
    log_warn "INSTALL_GRUB_THEME=OFF — se omite."
    exit 0
fi
if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] apt install desktop-base + update-grub" | tee -a "$LOG"
    exit 0
fi
if command -v update-grub &>/dev/null; then
    apt_install_resilient desktop-base || true
    update-grub || true
    log "-> GRUB actualizado con tema gráfico (desktop-base)"
else
    log_warn "update-grub no disponible (bootloader distinto). Se omite el tema GRUB."
fi
