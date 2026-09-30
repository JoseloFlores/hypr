#!/bin/bash
# updates-apply.sh — Despliega el plugin local jo/updates-debian y lo deja
# habilitado en Noctalia. Idempotente: re-ejecutable tras reinstall.
#
# Hace:
#   1. Copia noctalia/plugins/updates-debian -> ~/.local/share/noctalia/plugins/updates-debian
#   2. Merge conservador en ~/.local/state/noctalia/settings.toml (backup previo):
#      [plugins].enabled += id, [widget.updates], "updates" en bar.default.end
#   3. Si Noctalia corre: plugins enable -> config-reload -> validate.
#
# Uso:
#   ./noctalia/updates-apply.sh        # desde el repo
#   ~/.config/hypr/updates-apply.sh    # copia desplegada
set -eo pipefail

SELF_DIR="$(dirname "$(readlink -f "$0")")"
REAL_USER="$(logname 2>/dev/null || echo "$USER")"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ] && USER_HOME="$HOME"

PLUGIN_ID="jo/updates-debian"
SETTINGS="$USER_HOME/.local/state/noctalia/settings.toml"
DEST="$USER_HOME/.local/share/noctalia/plugins/updates-debian"

# Origen: repo (noctalia/plugins/updates-debian junto a este script o un nivel arriba).
SRC=""
for c in "$SELF_DIR/plugins/updates-debian" "$SELF_DIR/../noctalia/plugins/updates-debian" "$SELF_DIR/updates-debian"; do
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
run_as_user chmod +x "$DEST/scripts/check-updates.sh" "$DEST/scripts/upgrade.sh"
echo "[OK] plugin copiado a $DEST"

# --- 2. Merge settings.toml ---
if [ ! -f "$SETTINGS" ]; then
    echo "[WARN] no existe $SETTINGS (re-ejecuta tras el primer login)" >&2
    exit 0
fi
BK="$SETTINGS.bak-updates-apply-$(date +%Y%m%d_%H%M%S)"
run_as_user cp -f "$SETTINGS" "$BK"
echo "-> backup en $BK"
run_as_user python3 - "$SETTINGS" <<'PYEOF'
import re, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
orig = src
pid = "jo/updates-debian"

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

if not re.search(r'(?m)^\[widget\.updates\]', src):
    src += '\n[widget.updates]\ntype = "jo/updates-debian:updates"\n'
    print("added [widget.updates]")
else:
    print("[widget.updates] exists")

if '"updates"' not in src:
    m = re.search(r'(?m)^(\s*)"screenshot",\s*$', src)
    if m:
        src = src[:m.end()] + f'\n{m.group(1)}"updates",' + src[m.end():]
        print('added "updates" to bar end')
    else:
        print('WARN: sin ancla "screenshot", agrega "updates" a mano')
else:
    print('"updates" already in bar')

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
    echo "[OK] updates-debian activo + config valida"
else
    echo "[WARN] validate reporta avisos; revisa settings.toml"
fi
