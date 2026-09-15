#!/bin/bash
# =============================================================================
#  hypr — install-scripts/Global_functions.sh
#  Funciones compartidas para todos los módulos (logging, apt resiliente,
#  detección de usuario/SO/GPU, dry-run).
#  Cada módulo hace: source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"
# =============================================================================
# shellcheck disable=SC2034

# --- Colores (resiliente a shells no interactivas) ---
if tput sgr0 >/dev/null 2>&1; then
    OK="$(tput setaf 2)[OK]$(tput sgr0)"
    ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
    NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
    INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
    WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
else
    OK="[OK]"; ERROR="[ERROR]"; NOTE="[NOTE]"; INFO="[INFO]"; WARN="[WARN]"
fi

# --- Rutas compartidas ---
# REPO_ROOT: /home/jo/hypr (donde está install.sh). SCRIPT_DIR puede venir del orquestador.
if [ -z "${REPO_ROOT:-}" ]; then
    _GF_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
    _GF_DIR="$(dirname "$_GF_SELF")"
    REPO_ROOT="$(dirname "$_GF_DIR")"
fi
SCRIPT_DIR="${SCRIPT_DIR:-$REPO_ROOT}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/Install-Logs}"
mkdir -p "$LOG_DIR" 2>/dev/null || true
# LOG: cada módulo lo redefine a Install-Logs/NN-nombre-fecha.log; fallback común.
LOG="${LOG:-$LOG_DIR/00-common-$(date +%d-%H%M%S).log}"

DRY_RUN="${DRY_RUN:-0}"

log()  { echo -e "${INFO} $*" | tee -a "$LOG"; }
log_ok()   { echo -e "${OK} $*" | tee -a "$LOG"; }
log_warn() { echo -e "${WARN} $*" | tee -a "$LOG"; }
log_error(){ echo -e "${ERROR} $*" | tee -a "$LOG" >&2; }

# Ejecuta comando respetando DRY_RUN=1 (solo imprime, no toca sistema).
run_cmd() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] $*" | tee -a "$LOG"
        return 0
    fi
    "$@"
}

run_bash() {
    # run_bash "descripcion" cmd args...
    local desc="$1"; shift
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] ($desc) $*" | tee -a "$LOG"
        return 0
    fi
    "$@"
}

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# --- APT resiliente (extraído 1:1 de install.sh original) ---
apt_install_resilient() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] apt-get install -y --no-install-recommends $*" | tee -a "$LOG"
        return 0
    fi
    local max_attempts=5
    local attempt=1
    local delay=4
    until apt-get install -y --no-install-recommends "$@"; do
        if [ "$attempt" -ge "$max_attempts" ]; then
            log_error "Falló 'apt-get install' tras $max_attempts intentos para: $*"
            return 1
        fi
        log_warn "Falló descarga/instalación (intento $attempt/$max_attempts). Reintentando en ${delay}s..."
        sleep "$delay"
        dpkg --configure -a || true
        apt-get --fix-broken install -y || true
        apt-get update -o Acquire::Retries=3 || true
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
}

apt_update_resilient() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] apt-get update" | tee -a "$LOG"
        return 0
    fi
    local max_attempts=5
    local attempt=1
    local delay=4
    until apt-get update; do
        if [ "$attempt" -ge "$max_attempts" ]; then
            log_error "Falló 'apt-get update' tras $max_attempts intentos."
            return 1
        fi
        log_warn "Falló 'apt-get update' (intento $attempt/$max_attempts). Reintentando en ${delay}s..."
        sleep "$delay"
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
}

apt_hypr_stack() {
    if [ "${OS_CODENAME:-trixie}" = "trixie" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            echo "[DRY-RUN] apt-get install -y --no-install-recommends -t trixie-backports $*" | tee -a "$LOG"
            return 0
        fi
        apt_install_resilient -t trixie-backports "$@"
    else
        apt_install_resilient "$@"
    fi
}

# --- Detección compartida (idempotente, con fallback si el orquestador no exportó) ---
detect_user() {
    if [ -n "${REAL_USER:-}" ] && [ -n "${USER_HOME:-}" ] && [ -d "${USER_HOME:-}" ]; then
        return 0
    fi
    REAL_USER="${SUDO_USER:-${DOAS_USER:-$(logname 2>/dev/null || echo "${USER:-$(whoami)}")}}"
    [ "$REAL_USER" = "root" ] && [ -n "${SUDO_USER:-}" ] && REAL_USER="$SUDO_USER"
    USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
    [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ] && USER_HOME="$(eval echo ~"$REAL_USER")"
    if [ ! -d "$USER_HOME" ]; then
        log_error "No se encontró HOME para $REAL_USER"
        return 1
    fi
    export REAL_USER USER_HOME
}

detect_os() {
    if [ -n "${OS_CODENAME:-}" ]; then
        return 0
    fi
    # shellcheck disable=SC1091
    source /etc/os-release 2>/dev/null || true
    OS_CODENAME="${VERSION_CODENAME:-}"
    if [ -z "$OS_CODENAME" ]; then
        OS_CODENAME=$(grep -oE 'trixie|forky|bookworm|sid' <<< "${VERSION:-}" | head -n1 || true)
    fi
    if [ -z "$OS_CODENAME" ]; then
        log_warn "No se pudo detectar VERSION_CODENAME, usando 'trixie' por defecto."
        OS_CODENAME="trixie"
    fi
    if [ "${ID:-}" != "debian" ]; then
        log_warn "ID detectado es '${ID:-desconocido}', esperado 'debian'. Continuando de todos modos."
    fi
    if [[ "$OS_CODENAME" != "trixie" && "$OS_CODENAME" != "forky" ]]; then
        log_warn "OS detectado es $OS_CODENAME. Pensado para trixie o forky."
    fi
    export OS_CODENAME
}

detect_gpu() {
    if [ -n "${GPU_TYPE:-}" ]; then
        return 0
    fi
    GPU_TYPE="generic"
    if lspci 2>/dev/null | grep -iq "nvidia"; then
        GPU_TYPE="nvidia"
    elif lspci 2>/dev/null | grep -iq "amd.*\(vga\|display\|graphics\)\|Advanced Micro Devices"; then
        GPU_TYPE="amd"
    elif lspci 2>/dev/null | grep -iq "intel.*\(graphics\|display\|vga\)"; then
        GPU_TYPE="intel"
    fi
    # NVIDIA_MODE: auto (por defecto) | ON | OFF — permite preset desactivar driver propietario
    if [ "${NVIDIA_MODE:-auto}" = "OFF" ] && [ "$GPU_TYPE" = "nvidia" ]; then
        GPU_TYPE="generic"
    fi
    export GPU_TYPE
}

common_init() {
    # Uso: common_init "10-repos"  → define LOG y detecta user/os/gpu
    local mod_name="${1:-module}"
    LOG="$LOG_DIR/${mod_name}-$(date +%d-%H%M%S).log"
    export LOG
    detect_user || return 1
    detect_os || return 1
    detect_gpu || return 1
}
