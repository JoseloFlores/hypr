#!/bin/bash
# 60-greetd.sh — Greetd + tuigreet tty1 (paso 6/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "60-greetd"

log "6/10 Configurando greetd..."

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] /etc/greetd/config.toml + usermod video/render/input + override Restart=always" | tee -a "$LOG"
    exit 0
fi

mkdir -p /etc/greetd
mkdir -p /var/cache/tuigreet
chown -R _greetd: /var/cache/tuigreet || true
chmod 0755 /var/cache/tuigreet || true

cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1
[default_session]
# Hyprland capital H = binario/sesión wayland de Debian (coherente con README y hyprland.desktop).
command = "/usr/bin/tuigreet --time --remember --remember-session --asterisks --sessions /usr/share/wayland-sessions --cmd Hyprland"
user = "_greetd"
EOF

usermod -aG video,render,input _greetd || true
usermod -aG video,render,input,audio "$REAL_USER" || true
# Grupo input opcional — como InputGroup.sh de Debian-Hyprland
if [ "${INSTALL_INPUT_GROUP:-ON}" != "OFF" ]; then
    usermod -aG input "$REAL_USER" || true
fi

mkdir -p /etc/systemd/system/greetd.service.d/
cat > /etc/systemd/system/greetd.service.d/override.conf <<EOF
[Service]
Restart=always
RestartSec=5
EOF
systemctl daemon-reload
log_ok "Greetd OK"
