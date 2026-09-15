#!/bin/bash
# 20-drivers.sh — Hardware y drivers gráficos (paso 2/10 original)
set -eo pipefail
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
common_init "20-drivers"

log "2/10 Detectando hardware e instalando drivers gráficos... (GPU=$GPU_TYPE)"

# Base gráfica y DRM/Seat esencial para cualquier entorno (físico o VM)
apt_install_resilient libgl1-mesa-dri mesa-vulkan-drivers libegl-mesa0 libglx-mesa0 xwayland seatd libseat1 || true

if grep -qi "GenuineIntel" /proc/cpuinfo; then
    apt_install_resilient intel-microcode || true
elif grep -qi "AuthenticAMD" /proc/cpuinfo; then
    apt_install_resilient amd64-microcode || true
fi

if [ "$GPU_TYPE" = "nvidia" ]; then
    apt_install_resilient nvidia-driver nvidia-vaapi-driver || true
elif [ "$GPU_TYPE" = "amd" ]; then
    apt_install_resilient mesa-va-drivers mesa-vdpau-drivers va-driver-all || true
elif [ "$GPU_TYPE" = "intel" ]; then
    apt_install_resilient intel-media-va-driver i965-va-driver va-driver-all || true
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] apt-cache madison intel-media-va-driver-non-free && apt-get install ..." | tee -a "$LOG"
    else
        apt-cache madison intel-media-va-driver-non-free &>/dev/null \
            && apt-get install -y --no-install-recommends intel-media-va-driver-non-free || true
    fi
else
    log "-> GPU genérica/VM: solo base Mesa."
fi
apt_install_resilient firmware-linux-nonfree firmware-sof-signed || true
log_ok "Drivers OK (GPU=$GPU_TYPE)"
