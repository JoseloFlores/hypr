#!/bin/bash
# =============================================================================
#  Hyprland & Noctalia Installer - Debian 13 (Trixie) / 14 (Forky)
#  ORQUESTADOR modular (refactor del monolito install.sh).
#  Original completo respaldado en: install.sh.monolitico.bak
#
#  Uso compatible:            sudo ./install.sh
#  Con preset:                sudo ./install.sh --preset preset.example.sh
#  Solo dots + check:         sudo ./install.sh --only 70-dots,99-final-check
#  Simulación sin tocar nada: ./install.sh --dry-run [--only ...] [--preset ...]
#  Ver módulos:               ./install.sh --check
#  Módulo suelto:             sudo ./install-scripts/70-dots.sh
#                             DRY_RUN=1 ./install-scripts/70-dots.sh
# =============================================================================
set -eo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
SCRIPT_DIR="$REPO_ROOT"
LOG_DIR="$REPO_ROOT/Install-Logs"
mkdir -p "$LOG_DIR"
ORCH_LOG="$LOG_DIR/00-orchestrator-$(date +%d-%H%M%S).log"
# Compat: además del log por módulo, todo el output va a install.log como antes.
exec > >(tee -i "$REPO_ROOT/install.log" | tee -a "$ORCH_LOG") 2>&1

echo "=== Hyprland Installer (modular) — Debian Trixie/Forky — $(date) ==="

PRESET_FILE=""
ONLY_LIST=""
SKIP_LIST=""
DRY_RUN="0"
CHECK_ONLY=0

usage() {
    cat <<'EOF'
Uso:
  sudo ./install.sh [--preset FILE] [--only a,b] [--skip c] [--dry-run] [--check]

   Módulos: 10-repos 20-drivers 30-base 40-hypr 50-fonts 60-greetd 70-dots
            71-noctalia 80-pam-portals 90-services 95-grub 99-final-check

Ejemplos:
  sudo ./install.sh
  sudo ./install.sh --preset preset.example.sh
  sudo ./install.sh --only 70-dots,99-final-check
  ./install.sh --dry-run --only 70-dots
  ./dry-run-build.sh --only 70-dots
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --preset) PRESET_FILE="${2:-}"; shift 2;;
        --only) ONLY_LIST="${2:-}"; shift 2;;
        --skip) SKIP_LIST="${2:-}"; shift 2;;
        --dry-run) DRY_RUN="1"; shift;;
        --check) CHECK_ONLY=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "Arg desconocido: $1" >&2; usage; exit 2;;
    esac
done

# --- Defaults preset (todo ON = comportamiento original) ---
REPOS="ON"; DRIVERS="ON"; BASE="ON"; HYPR="ON"; FONTS="ON"; GREETD="ON"
DOTS="ON"; NOCTALIA="ON"; PAM="ON"; SERVICES="ON"; GRUB="ON"
NVIDIA_MODE="auto"
INSTALL_THUNAR="ON"; INSTALL_MEDIA="ON"; INSTALL_INPUT_GROUP="ON"
INSTALL_GRUB_THEME="ON"; INSTALL_SDDM="OFF"
INSTALL_FIREFOX="ON"; INSTALL_THUNDERBIRD="OFF"
WALLPAPER_URL=""; WALLPAPER_DIR="$HOME/Imágenes/wallpapers/wallpaper"

if [ -n "$PRESET_FILE" ]; then
    [ -f "$PRESET_FILE" ] || { echo "ERROR: preset no encontrado: $PRESET_FILE" >&2; exit 1; }
    # shellcheck disable=SC1090
    source "$PRESET_FILE"
    echo "-> Preset cargado: $PRESET_FILE"
fi

ALL_MODULES=(10-repos 20-drivers 30-base 40-hypr 50-fonts 60-greetd 70-dots 71-noctalia 80-pam-portals 90-services 95-grub 99-final-check)
# Preset OFF => skip implícito
declare -a PRESET_SKIPS=()
[ "$REPOS" = "OFF" ] && PRESET_SKIPS+=(10-repos)
[ "$DRIVERS" = "OFF" ] && PRESET_SKIPS+=(20-drivers)
[ "$BASE" = "OFF" ] && PRESET_SKIPS+=(30-base)
[ "$HYPR" = "OFF" ] && PRESET_SKIPS+=(40-hypr)
[ "$FONTS" = "OFF" ] && PRESET_SKIPS+=(50-fonts)
[ "$GREETD" = "OFF" ] && PRESET_SKIPS+=(60-greetd)
[ "$DOTS" = "OFF" ] && PRESET_SKIPS+=(70-dots)
[ "$NOCTALIA" = "OFF" ] && PRESET_SKIPS+=(71-noctalia)
[ "$PAM" = "OFF" ] && PRESET_SKIPS+=(80-pam-portals)
[ "$SERVICES" = "OFF" ] && PRESET_SKIPS+=(90-services)
[ "$GRUB" = "OFF" ] && PRESET_SKIPS+=(95-grub)

MODULES=()
if [[ -n "$ONLY_LIST" ]]; then
    IFS=',' read -r -a MODULES <<< "$ONLY_LIST"
else
    MODULES=("${ALL_MODULES[@]}")
fi
# Aplicar skips de preset + --skip
_combined_skip="$(IFS=,; echo "${PRESET_SKIPS[*]}${PRESET_SKIPS:+${SKIP_LIST:+,}}$SKIP_LIST")"
if [[ -n "$_combined_skip" ]]; then
    IFS=',' read -r -a _SK <<< "$_combined_skip"
    FILTERED=()
    for m in "${MODULES[@]}"; do
        skip_it=0
        for s in "${_SK[@]}"; do [[ "$m" == "$s" ]] && skip_it=1; done
        [[ $skip_it -eq 0 ]] && FILTERED+=("$m")
    done
    MODULES=("${FILTERED[@]}")
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
    printf "%-18s %s\n" "MODULO" "SCRIPT"
    for m in "${MODULES[@]}"; do printf "%-18s %s\n" "$m" "$REPO_ROOT/install-scripts/$m.sh"; done
    exit 0
fi

if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" != "1" ]; then
    echo "ERROR: Ejecuta con sudo: sudo ./install.sh" >&2
    exit 1
fi

# --- Detección temprana (se exporta a los módulos) ---
# shellcheck disable=SC1091
source /etc/os-release 2>/dev/null || true
OS_CODENAME="${VERSION_CODENAME:-}"
if [ -z "$OS_CODENAME" ]; then
    OS_CODENAME=$(grep -oE 'trixie|forky|bookworm|sid' <<< "${VERSION:-}" | head -n1 || true)
fi
[ -z "$OS_CODENAME" ] && OS_CODENAME="trixie"

REAL_USER="${SUDO_USER:-${DOAS_USER:-$(logname 2>/dev/null || echo "${USER:-$(whoami)}")}}"
[ "$REAL_USER" = "root" ] && [ -n "${SUDO_USER:-}" ] && REAL_USER="$SUDO_USER"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ] && USER_HOME="$(eval echo ~"$REAL_USER")"

GPU_TYPE="generic"
if lspci 2>/dev/null | grep -iq "nvidia"; then GPU_TYPE="nvidia";
elif lspci 2>/dev/null | grep -iq "amd.*\(vga\|display\|graphics\)\|Advanced Micro Devices"; then GPU_TYPE="amd";
elif lspci 2>/dev/null | grep -iq "intel.*\(graphics\|display\|vga\)"; then GPU_TYPE="intel"; fi
if [ "$NVIDIA_MODE" = "OFF" ] && [ "$GPU_TYPE" = "nvidia" ]; then GPU_TYPE="generic"; fi

export REPO_ROOT SCRIPT_DIR LOG_DIR DRY_RUN OS_CODENAME REAL_USER USER_HOME GPU_TYPE
export NVIDIA_MODE INSTALL_THUNAR INSTALL_MEDIA INSTALL_INPUT_GROUP INSTALL_GRUB_THEME
export INSTALL_NOCTALIA INSTALL_FIREFOX INSTALL_THUNDERBIRD WALLPAPER_URL WALLPAPER_DIR

echo "-> Sistema: Debian $OS_CODENAME | Usuario: $REAL_USER | GPU: $GPU_TYPE | DRY_RUN=$DRY_RUN"
echo "-> Módulos: ${MODULES[*]}"
if ! ping -c1 -W3 deb.debian.org &>/dev/null; then
    echo "ADVERTENCIA: Sin conectividad a deb.debian.org — intentando continuar..."
fi

execute_script() {
    local mod="$1"
    local script="$REPO_ROOT/install-scripts/$mod.sh"
    if [ ! -f "$script" ]; then
        echo "ERROR: falta módulo $script" >&2
        return 1
    fi
    chmod +x "$script" || true
    echo ""
    echo "===== [$mod] ====="
    bash "$script"
}

FAILED=()
for mod in "${MODULES[@]}"; do
    if ! execute_script "$mod"; then
        echo "ERROR en módulo $mod" >&2
        FAILED+=("$mod")
        # 99-final-check nunca bloquea; el resto sí aborta salvo dry-run
        if [ "$DRY_RUN" != "1" ]; then
            echo "Abortando. Revisa $LOG_DIR" >&2
            exit 1
        fi
    fi
done

# SDDM opcional (no era parte del original; OFF por defecto)
if [ "${INSTALL_SDDM:-OFF}" = "ON" ] && [ "$DRY_RUN" != "1" ]; then
    echo "===== [sddm opcional] ====="
    apt-get install -y --no-install-recommends sddm || true
fi

echo ""
echo "Logs por módulo en: $LOG_DIR (y resumen en ./install.log)"
if [ ${#FAILED[@]} -gt 0 ]; then
    echo "Módulos con fallo (dry-run): ${FAILED[*]}" >&2
    exit 1
fi
echo "Reinicia: sudo reboot"
