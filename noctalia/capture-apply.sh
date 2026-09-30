#!/bin/bash
# capture-apply.sh — Despliega el plugin local jo/capture (foto+video en un
# solo widget) y lo deja habilitado en Noctalia. Idempotente.
#
# Hace:
#   1. Copia noctalia/plugins/capture -> ~/.local/share/noctalia/plugins/capture
#   2. Merge conservador en ~/.local/state/noctalia/settings.toml (backup previo):
#      [plugins].enabled += id, [plugin_settings."jo/capture"] (solo claves
#      ausentes), [widget.capture] type="jo/capture:capture",
#      bar.default.end: "screenshot" -> "capture" (un solo icono).
#   3. Si Noctalia corre: plugins enable -> config-reload -> validate.
#
# Uso:
#   ./noctalia/capture-apply.sh         # desde el repo
#   ~/.config/hypr/capture-apply.sh     # copia desplegada
set -eo pipefail

SELF_DIR="$(dirname "$(readlink -f "$0")")"
REAL_USER="$(logname 2>/dev/null || echo "$USER")"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ] && USER_HOME="$HOME"

PLUGIN_ID="jo/capture"
SETTINGS="$USER_HOME/.local/state/noctalia/settings.toml"
DEST="$USER_HOME/.local/share/noctalia/plugins/capture"

# Origen: repo (noctalia/plugins/capture junto a este script o un nivel arriba).
SRC=""
for c in "$SELF_DIR/plugins/capture" "$SELF_DIR/../noctalia/plugins/capture" "$SELF_DIR/capture"; do
    if [ -f "$c/plugin.toml" ]; then SRC="$c"; break; fi
done
if [ -z "$SRC" ]; then
    echo "[WARN] no se encontro el plugin fuente (buscado desde $SELF_DIR)" >&2
    exit 1
fi

run_as_user() {
    if [ "$(whoami)" = "$REAL_USER" ]; then
        env HOME="$USER_HOME" "$@"
    else
        sudo -u "$REAL_USER" env HOME="$USER_HOME" "$@"
    fi
}

# --- 1. Copia ---
run_as_user mkdir -p "$DEST"
run_as_user cp -r "$SRC/." "$DEST/"
echo "[OK] plugin copiado a $DEST"

# --- 1b. Dir de videos ---
run_as_user mkdir -p "$USER_HOME/Vídeos/Recordings"

# --- 2. Merge settings.toml ---
if [ ! -f "$SETTINGS" ]; then
    echo "[WARN] no existe $SETTINGS (re-ejecuta tras el primer login)" >&2
    exit 0
fi
BK="$SETTINGS.bak-capture-apply-$(date +%Y%m%d_%H%M%S)"
run_as_user cp -f "$SETTINGS" "$BK"
echo "-> backup en $BK"
run_as_user python3 - "$SETTINGS" <<'PYEOF'
import re, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
orig = src
pid = "jo/capture"

m = re.search(r'(?m)^\[plugins\]\s*$', src)
if m:
    tail = src[m.end():]
    nxt = re.search(r'(?m)^\[', tail)
    seg = tail[:nxt.start()] if nxt else tail
    em = re.search(r'(?m)^enabled\s*=\s*\[(.*?)\]', seg)
    if em and pid not in em.group(1):
        new = em.group(1).rstrip() + (", " if em.group(1).strip() else "") + f'"{pid}"'
        src = src[:m.end()+em.start(1)] + new + src[m.end()+em.end(1):]
        print(f"added {pid} to [plugins].enabled")
    elif not em:
        src = src[:m.end()] + f'\nenabled = ["{pid}"]\n' + src[m.end():]
        print("added enabled list to [plugins]")
    else:
        print("already enabled")
else:
    src += ("" if src.endswith("\n") else "\n") + f'\n[plugins]\nenabled = ["{pid}"]\n'
    print("created [plugins]")

# plugin_settings del plugin (solo si ausente; respeta cambios del usuario en GUI)
sec = f'[plugin_settings."{pid}"]'
if sec not in src:
    src += ("" if src.endswith("\n") else "\n") + f"""
{sec}
audio_source = "none"
directory = "__HOME__/Vídeos/Recordings"
filename_pattern = "Video_%Y%m%d_%H%M%S"
frame_rate = 30
video_codec = "h264"
"""
    print(f"added {sec}")
else:
    print(f"{sec} exists")

if not re.search(r'(?m)^\[widget\.capture\]', src):
    src += '\n[widget.capture]\ntype = "jo/capture:capture"\n'
    print("added [widget.capture]")
else:
    print("[widget.capture] exists")

# NOTA: no se escribe [widget.capture.actions] por instancia: el manifest ya
# declara middle="none" como default (libera el boton medio para foto-pantalla)
# y el validator 5.1.0 avisa "unknown setting" en esa seccion para widgets plugin.

# Un solo icono: reemplaza "screenshot" por "capture" en bar end.
# Si ya existe "capture", solo retira el "screenshot" builtin duplicado.
if '"capture"' not in src:
    m = re.search(r'(?m)^(\s*)"screenshot",\s*$', src)
    if m:
        src = src[:m.start()] + f'{m.group(1)}"capture",' + src[m.end():]
        print('replaced "screenshot" with "capture" in bar end')
    else:
        print('WARN: sin ancla "screenshot", agrega "capture" a mano en bar end')
else:
    print('"capture" already in bar')
    m = re.search(r'(?m)^(\s*)"screenshot",\s*$', src)
    if m:
        src = src[:m.start()] + src[m.end():]
        print('removed duplicate builtin "screenshot" (capture lo reemplaza)')

src = src.replace("__HOME__", __import__("os").environ.get("HOME", "~"))
if src != orig:
    open(path, "w", encoding="utf-8").write(src)
    print("settings.toml actualizado")
else:
    print("settings.toml sin cambios")
PYEOF

# --- 3. Enable + reload ---
if ! run_as_user pgrep -x noctalia >/dev/null 2>&1; then
    echo "[WARN] Noctalia no corre; re-ejecuta tras el login."
    exit 0
fi
run_as_user noctalia msg plugins enable "$PLUGIN_ID" >/dev/null 2>&1 || true
sleep 2
run_as_user noctalia msg config-reload >/dev/null 2>&1 || true
sleep 2
if run_as_user noctalia config validate >/dev/null 2>&1; then
    echo "[OK] jo/capture activo + config valida"
else
    echo "[WARN] validate reporta avisos; revisa settings.toml"
fi
