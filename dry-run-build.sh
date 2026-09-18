#!/bin/bash
# dry-run-build.sh — Compila-nada, solo valida módulos (equiv. a dry-run-build.sh de Debian-Hyprland)
# Uso:
#   ./dry-run-build.sh                       # todos los módulos en dry-run
#   ./dry-run-build.sh --only 70-dots,99-final-check
#   ./dry-run-build.sh --skip 20-drivers,95-grub
#   ./dry-run-build.sh --check                # lista módulos sin ejecutar
set -u
set -o pipefail
REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DEFAULT_MODULES=(10-repos 20-drivers 30-base 40-hypr 50-fonts 60-greetd 70-dots 71-quickshell 80-pam-portals 90-services 95-grub 99-final-check)
ONLY_LIST=""; SKIP_LIST=""; CHECK_ONLY=0

usage() { echo "Uso: $0 [--only a,b] [--skip c] [--check]"; }
while [[ $# -gt 0 ]]; do
    case "$1" in
        --only) ONLY_LIST="${2:-}"; shift 2;;
        --skip) SKIP_LIST="${2:-}"; shift 2;;
        --check) CHECK_ONLY=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "Arg desconocido: $1" >&2; usage; exit 2;;
    esac
done

MODULES=()
if [[ -n "$ONLY_LIST" ]]; then IFS=',' read -r -a MODULES <<< "$ONLY_LIST";
else MODULES=("${DEFAULT_MODULES[@]}"); fi
if [[ -n "$SKIP_LIST" ]]; then
    IFS=',' read -r -a _SK <<< "$SKIP_LIST"; F=()
    for m in "${MODULES[@]}"; do skip=0; for s in "${_SK[@]}"; do [[ "$m" == "$s" ]] && skip=1; done; [[ $skip -eq 0 ]] && F+=("$m"); done
    MODULES=("${F[@]}")
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
    printf "%-18s %s\n" "MODULO" "SCRIPT"
    for m in "${MODULES[@]}"; do printf "%-18s %s\n" "$m" "$REPO_ROOT/install-scripts/$m.sh"; done
    exit 0
fi

declare -A RESULTS
TS=$(date +%F-%H%M%S)
SUMMARY="$REPO_ROOT/Install-Logs/build-dry-run-$TS.log"
echo "[INFO] dry-run $TS" | tee "$SUMMARY"
for mod in "${MODULES[@]}"; do
    sp="$REPO_ROOT/install-scripts/$mod.sh"
    echo "=== $mod (DRY RUN) ===" | tee -a "$SUMMARY"
    if [[ ! -f "$sp" ]]; then echo "[WARN] falta $sp" | tee -a "$SUMMARY"; RESULTS[$mod]="MISSING"; continue; fi
    if DRY_RUN=1 REPO_ROOT="$REPO_ROOT" bash "$sp" >> "$SUMMARY" 2>&1; then RESULTS[$mod]="PASS"; else RESULTS[$mod]="FAIL"; fi
done
printf "\nSummary (dry-run):\n" | tee -a "$SUMMARY"
for mod in "${MODULES[@]}"; do printf "%-18s %s\n" "$mod" "${RESULTS[$mod]:-SKIPPED}" | tee -a "$SUMMARY"; done
echo "Logs: $SUMMARY + Install-Logs/" | tee -a "$SUMMARY"
failed=0; for mod in "${MODULES[@]}"; do [[ "${RESULTS[$mod]:-}" == "FAIL" ]] && failed=1; done
exit $failed
