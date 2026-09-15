#!/bin/bash
# 10-repos.sh — Repositorios Debian (contrib non-free non-free-firmware + backports)
# Extraído 1:1 del paso 1/10 de install.sh original.
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "10-repos"

log "1/10 Configurando repositorios (contrib non-free non-free-firmware)..."

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] parchear /etc/apt/sources.list + *.sources + backports si trixie + apt-get update" | tee -a "$LOG"
    exit 0
fi

mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99resilient <<'EOF'
Acquire::Retries "5";
Acquire::http::Timeout "20";
Acquire::https::Timeout "20";
APT::Get::Assume-Yes "true";
EOF

if [ -f /etc/apt/sources.list ]; then
    sed -i -E '/^deb(-src)?\s+http:\/\/(deb\.debian\.org|security\.debian\.org)/ {
        /contrib/! s/main/main contrib/
        /non-free-firmware/! s/main/main non-free-firmware/
        /non-free/! s/main/main non-free/
    }' /etc/apt/sources.list
fi

for src in /etc/apt/sources.list.d/*.sources; do
    [ -f "$src" ] || continue
    if grep -q "^Components:" "$src" && grep -qE "(deb\.debian\.org|security\.debian\.org)" "$src"; then
        sed -i -E 's/^Components:.*/Components: main contrib non-free non-free-firmware/' "$src" || true
    fi
done

if [ "$OS_CODENAME" = "trixie" ]; then
    cat > /etc/apt/sources.list.d/trixie-backports.list <<EOF
deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
EOF
    log "-> Backports asegurado para Trixie"
fi

apt_update_resilient
log_ok "Repos OK ($OS_CODENAME)"
