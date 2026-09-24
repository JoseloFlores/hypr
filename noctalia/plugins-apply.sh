#!/bin/bash
# plugins-apply.sh — Aplica el estado de plugins Noctalia de este repo al sistema.
# Idempotente: se puede re-ejecutar tras `plugins update community` o en un reinstall.
#
# Hace (solo si NOCTALIA_PLUGINS != OFF):
#   1. Merge conservador en ~/.local/state/noctalia/settings.toml (backup previo):
#      plugin h-jangra/region-recorder habilitado + sus settings + widget
#      `recorder` en la barra + auto_update="official" (protege el parche local).
#   2. mkdir -p ~/Vídeos/Recordings
#   3. Si Noctalia está corriendo: plugins enable -> espera materialización ->
#      aplica noctalia/plugins/region-recorder-wf-fix.patch -> config-reload -> validate.
#      Si NO corre: deja settings.toml listo y avisa re-ejecutar tras el primer login.
#
# Uso:
#   NOCTALIA_PLUGINS=ON DRY_RUN=0 ./noctalia/plugins-apply.sh        # desde el repo
#   ~/.config/hypr/noctalia-plugins-apply.sh                          # copia desplegada
# Vars: REAL_USER/USER_HOME (auto), REPO_ROOT (install), PLUGIN_PATCH (override).
set -eo pipefail

SELF_DIR="$(dirname "$(readlink -f "$0")")"
if [ -f "$SELF_DIR/Global_functions.sh" ]; then
    # Contexto install-scripts/: logging del repo.
    source "$SELF_DIR/Global_functions.sh"
    common_init "plugins-apply" || true
else
    # Standalone (ej. ~/.config/hypr/): logging mínimo.
    LOG_DIR="${LOG_DIR:-/tmp}"
    LOG="${LOG:-$LOG_DIR/noctalia-plugins-apply.log}"
    log() { echo "[..] $*"; }
    log_ok() { echo "[OK] $*"; }
    log_warn() { echo "[WARN] $*" >&2; }
    if [ -z "${REAL_USER:-}" ]; then
        REAL_USER="$(logname 2>/dev/null || echo "$USER")"
        USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
        [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ] && USER_HOME="$HOME"
        export REAL_USER USER_HOME
    fi
fi

DRY_RUN="${DRY_RUN:-0}"
if [ "${NOCTALIA_PLUGINS:-ON}" = "OFF" ]; then
    log "Plugins Noctalia desactivados por preset (NOCTALIA_PLUGINS=OFF), se omite."
    exit 0
fi

PLUGIN_ID="h-jangra/region-recorder"
SETTINGS="$USER_HOME/.local/state/noctalia/settings.toml"
MAT_DIR="$USER_HOME/.local/state/noctalia/plugins/materialized/community/region-recorder"
REC_DIR="$USER_HOME/Vídeos/Recordings"

# Localiza el parche: override > copia desplegada > repo.
PATCH_CANDIDATES=(
    "${PLUGIN_PATCH:-}"
    "$SELF_DIR/noctalia-plugins/region-recorder-wf-fix.patch"
    "${REPO_ROOT:-$SELF_DIR}/noctalia/plugins/region-recorder-wf-fix.patch"
    "$SELF_DIR/../noctalia/plugins/region-recorder-wf-fix.patch"
)
PATCH=""
for c in "${PATCH_CANDIDATES[@]}"; do
    if [ -n "$c" ] && [ -f "$c" ]; then PATCH="$c"; break; fi
done

run_as_user() {
    # Sin sudo si ya somos el usuario destino (ejecución manual post-login).
    if [ "$(whoami)" = "$REAL_USER" ]; then
        env HOME="$USER_HOME" "$@"
    else
        sudo -u "$REAL_USER" env HOME="$USER_HOME" "$@"
    fi
}

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] merge $SETTINGS (enabled+$PLUGIN_ID, plugin_settings, widget.recorder, bar.end+=recorder, auto_update=official)"
    echo "[DRY-RUN] mkdir $REC_DIR + plugins enable $PLUGIN_ID + patch $MAT_DIR/service.luau + config-reload + validate"
    exit 0
fi

# --- 1. Merge settings.toml (python3 stdlib, sin pisar valores del usuario) ---
if [ ! -f "$SETTINGS" ]; then
    log_warn "no existe $SETTINGS (¿Noctalia aún sin arrancar?). Se omite merge; re-ejecuta tras el primer login."
else
    BK="$SETTINGS.bak-plugins-apply-$(date +%Y%m%d_%H%M%S)"
    run_as_user cp -f "$SETTINGS" "$BK"
    log "-> backup settings.toml en $BK"
    run_as_user python3 - "$SETTINGS" <<'PYEOF'
import re, sys
path = sys.argv[1]
pid = "h-jangra/region-recorder"
src = open(path, encoding="utf-8").read()
orig = src

# [plugins].enabled += id
m = re.search(r'(?m)^enabled\s*=\s*\[(.*?)\]', src)
if m and pid not in m.group(1):
    src = src[:m.start(1)] + m.group(1).rstrip() + (", " if m.group(1).strip() else "") + f'"{pid}"' + src[m.end(1):]
    print(f"added {pid} to [plugins].enabled")
elif not m:
    print("WARN: no se encontró línea enabled = [...] en settings.toml")

# auto_update: solo si ausente (respeta valor del usuario si ya existe)
plug_sec = re.search(r'(?m)^\[plugins\]\s*$', src)
if plug_sec:
    tail = src[plug_sec.end():]
    nxt = re.search(r'(?m)^\[', tail)
    seg = tail[:nxt.start()] if nxt else tail
    if "auto_update" not in seg:
        anchor = re.search(r'(?m)^enabled\s*=\s*\[.*?\]', seg)
        ins = '\n# LOCAL (repo hypr): "official" para no auto-actualizar community y no perder el parche wf-recorder de region-recorder.\nauto_update = "official"'
        if anchor:
            pos = plug_sec.end() + anchor.end()
            src = src[:pos] + ins + src[pos:]
            print('set auto_update = "official"')
    else:
        print("auto_update ya definido por el usuario, se respeta")
else:
    print("WARN: no se encontró sección [plugins]")

# plugin_settings del plugin (solo claves ausentes)
sec = f'[plugin_settings."{pid}"]'
if sec not in src:
    src += ("" if src.endswith("\n") else "\n") + f"""
{sec}
audio_source = "none"
directory = "__HOME__/Vídeos/Recordings"
frame_rate = 30
show_cursor = true
video_codec = "h264"
video_source = "region"
"""
    print(f"added {sec}")
else:
    print(f"{sec} ya existe, no se toca")

# widget.recorder -> plugin
if not re.search(r'(?m)^\[widget\.recorder\]', src):
    src += '\n[widget.recorder]\ntype = "h-jangra/region-recorder:widget"\n'
    print("added [widget.recorder]")
else:
    print("[widget.recorder] ya existe, no se toca")

# bar.default end += "recorder" tras "screenshot"
if '"recorder"' not in src:
    m = re.search(r'(?m)^(\s*)"screenshot",\s*$', src)
    if m:
        src = src[:m.end()] + f'\n{m.group(1)}"recorder",' + src[m.end():]
        print('added "recorder" a bar end tras "screenshot"')
    else:
        print('WARN: no se encontró "screenshot" en bar end; añade "recorder" a mano')
else:
    print('"recorder" ya está en la barra')

src = src.replace("__HOME__", __import__("os").environ.get("HOME", "~"))
if src != orig:
    open(path, "w", encoding="utf-8").write(src)
    print("settings.toml actualizado")
else:
    print("settings.toml sin cambios")
PYEOF
fi

# --- 2. Directorio de grabaciones ---
run_as_user mkdir -p "$REC_DIR"
log "-> dir grabaciones $REC_DIR"

# --- 3. Enable + parche (solo con instancia corriendo) ---
if ! run_as_user pgrep -x noctalia >/dev/null 2>&1; then
    log_warn "Noctalia no está corriendo: settings.toml quedó listo."
    echo "       Tras el primer login re-ejecuta: ~/.config/hypr/noctalia-plugins-apply.sh"
    exit 0
fi

# Solo enable si no está habilitado: enable re-exporta en background y pisaría
# el parche aplicado abajo (race). Si ya está enabled, se salta.
# Reintentos: `list` puede fallar en ventanas de reload del shell.
# NOTA: no usar `... list | grep -q` directo: con `pipefail`, grep -q cierra
# el pipe antes de tiempo y `noctalia` muere por SIGPIPE (rc=141). Se captura
# la salida primero y se grepea sobre variable (sin pipe).
enabled_now=0
for _ in 1 2 3; do
    list_out="$(run_as_user noctalia msg plugins list 2>/dev/null || true)"
    if grep -q "$PLUGIN_ID.*enabled" <<<"$list_out"; then
        enabled_now=1
        break
    fi
    sleep 2
done
if [ "$enabled_now" = "1" ]; then
    log "-> $PLUGIN_ID ya habilitado (se omite enable para no re-exportar)"
else
    run_as_user noctalia msg plugins enable "$PLUGIN_ID" 2>&1 | tee -a "${LOG:-/dev/null}" || true
    # Espera fin de la exportación (usa dir .tmp-* y luego renombra).
    for _ in $(seq 1 30); do
        [ -f "$MAT_DIR/service.luau" ] || { sleep 2; continue; }
        if ls -d "$USER_HOME/.local/state/noctalia/plugins/materialized/community/.tmp-region-recorder-"* 2>/dev/null | grep -q .; then
            sleep 2; continue
        fi
        break
    done
    sleep 2 # asentamiento del rename
fi

svc="$MAT_DIR/service.luau"
if [ ! -f "$svc" ]; then
    log_warn "no se materializó $svc tras 60s (¿sin red?). Re-ejecuta este script luego."
    exit 0
fi

if [ -n "$PATCH" ]; then
    if grep -q "LOCAL FIX" "$svc" 2>/dev/null; then
        log "-> parche wf-recorder ya aplicado"
    elif run_as_user patch -p1 --forward -d "$MAT_DIR" < "$PATCH" >>"${LOG:-/dev/null}" 2>&1 \
        && grep -q "LOCAL FIX" "$svc" 2>/dev/null; then
        log_ok "parche wf-recorder aplicado y verificado"
    else
        log_warn "el parche no aplicó limpio (quizá upstream cambió). Revisa $svc a mano."
    fi
else
    log_warn "no se encontró region-recorder-wf-fix.patch; se omite parcheo."
fi

run_as_user noctalia msg config-reload >/dev/null 2>&1 || true
sleep 2
if run_as_user noctalia config validate >/dev/null 2>&1; then
    log_ok "Noctalia plugins OK ($PLUGIN_ID + validate)"
else
    log_warn "'noctalia config validate' reporta avisos; revisa ~/.config/noctalia/ y settings.toml"
fi
