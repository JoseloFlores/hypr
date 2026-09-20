#!/bin/bash
# foot_sync.sh — Sincroniza Foot + Fuzzel con la paleta pywal actual.
# Fuente de verdad: ~/.cache/wal/colors.json (generado por set-wallpaper.sh).
# Si no hay caché pywal, indica correr set-wallpaper.sh primero (exit 0 para no romper 70-dots).
set -u

WAL_JSON="$HOME/.cache/wal/colors.json"
FOOT_COLORS="$HOME/.config/foot/colors.ini"
FUZZEL_CONFIG="$HOME/.config/fuzzel/fuzzel.ini"

if [ ! -f "$WAL_JSON" ] || ! command -v jq &>/dev/null; then
    echo "foot_sync: sin paleta pywal en $WAL_JSON — ejecuta set-wallpaper.sh <imagen> primero."
    exit 0
fi

BG=$(jq -r '.special.background' "$WAL_JSON" | tr -d '#')
FG=$(jq -r '.special.foreground' "$WAL_JSON" | tr -d '#')
C0=$(jq -r '.colors.color0' "$WAL_JSON" | tr -d '#')
C1=$(jq -r '.colors.color1' "$WAL_JSON" | tr -d '#')
C2=$(jq -r '.colors.color2' "$WAL_JSON" | tr -d '#')
C3=$(jq -r '.colors.color3' "$WAL_JSON" | tr -d '#')
C4=$(jq -r '.colors.color4' "$WAL_JSON" | tr -d '#')
C5=$(jq -r '.colors.color5' "$WAL_JSON" | tr -d '#')
C6=$(jq -r '.colors.color6' "$WAL_JSON" | tr -d '#')
C7=$(jq -r '.colors.color7' "$WAL_JSON" | tr -d '#')

echo "Sincronizando Foot + Fuzzel con pywal."

# --- Foot ---
mkdir -p "$(dirname "$FOOT_COLORS")"
cat <<EOF > "$FOOT_COLORS"
# Generado por foot_sync.sh desde pywal — no editar a mano
[colors]
background=$BG
foreground=$FG
regular0=$C0
regular1=$C1
regular2=$C2
regular3=$C3
regular4=$C4
regular5=$C5
regular6=$C6
regular7=$C7
bright0=$C0
bright1=$C1
bright2=$C2
bright3=$C3
bright4=$C4
bright5=$C5
bright6=$C6
bright7=$C7
EOF
echo "Foot sincronizado -> $FOOT_COLORS"

# Asegurar foot.ini con include
FOOT_MAIN="$HOME/.config/foot/foot.ini"
REPO_FOOT_TEMPLATE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/foot.ini"
mkdir -p "$(dirname "$FOOT_MAIN")"
if [ ! -f "$FOOT_MAIN" ]; then
    if [ -f "$REPO_FOOT_TEMPLATE" ]; then
        cp -f "$REPO_FOOT_TEMPLATE" "$FOOT_MAIN"
        echo "Foot config creado desde plantilla: $FOOT_MAIN"
    else
        cat > "$FOOT_MAIN" <<FOOT_EOF
include=~/.config/foot/colors.ini
[main]
font=MesloLGM Nerd Font Mono:size=10
FOOT_EOF
    fi
else
    if ! grep -q "^include=.*colors.ini" "$FOOT_MAIN"; then
        tmp_foot=$(mktemp)
        echo "include=~/.config/foot/colors.ini" > "$tmp_foot"
        echo "" >> "$tmp_foot"
        cat "$FOOT_MAIN" >> "$tmp_foot"
        mv "$tmp_foot" "$FOOT_MAIN"
        echo "Foot config: añadido include colors.ini"
    fi
fi

# --- Fuzzel (translúcido, creación si falta) ---
mkdir -p "$(dirname "$FUZZEL_CONFIG")"
if [ ! -f "$FUZZEL_CONFIG" ]; then
    REPO_FUZZEL_TEMPLATE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/fuzzel.ini"
    [ -f "$REPO_FUZZEL_TEMPLATE" ] && cp -f "$REPO_FUZZEL_TEMPLATE" "$FUZZEL_CONFIG" \
        && echo "Fuzzel config creado desde plantilla: $FUZZEL_CONFIG"
fi

if [ -f "$FUZZEL_CONFIG" ]; then
python3 - "$FUZZEL_CONFIG" "$BG" "$FG" "$C4" <<'PYEOF'
import sys, re, pathlib
cfg_path, BG, FG, BLUE = sys.argv[1:5]
BG_T = BG + "e6"
FG_FF = FG + "ff"
BLUE_FF = BLUE + "ff"
BG_FF = BG + "ff"
PLACEHOLDER = FG + "80"
COUNTER = FG + "80"

desired = {
    "background": BG_T,
    "text": FG_FF,
    "prompt": FG_FF,
    "placeholder": PLACEHOLDER,
    "input": FG_FF,
    "match": BLUE_FF,
    "selection": BLUE_FF,
    "selection-text": BG_FF,
    "selection-match": FG_FF,
    "counter": COUNTER,
    "border": BLUE_FF,
}
border_desired = {"width": "1", "radius": "12"}

p = pathlib.Path(cfg_path)
text = p.read_text()

if "[colors]" not in text:
    text = text.rstrip() + "\n\n[colors]\n"
if "[border]" not in text:
    text = text.rstrip() + "\n\n[border]\nwidth=1\nradius=12\n"

lines = text.splitlines()
out = []
current = None
seen_colors = set()
seen_border = set()

for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        if current == "colors":
            for k, v in desired.items():
                if k not in seen_colors:
                    out.append(f"{k}={v}")
        if current == "border":
            for k, v in border_desired.items():
                if k not in seen_border:
                    out.append(f"{k}={v}")
        current = stripped[1:-1].strip()
        out.append(line)
        continue

    if current == "colors":
        m = re.match(r'^\s*#?\s*([a-zA-Z0-9\-_]+)\s*=\s*.*$', line)
        if m and m.group(1) in desired:
            out.append(f"{m.group(1)}={desired[m.group(1)]}")
            seen_colors.add(m.group(1))
            continue
        out.append(line)
    elif current == "border":
        m = re.match(r'^\s*([a-zA-Z0-9\-_]+)\s*=\s*.*$', line)
        if m and m.group(1) in border_desired:
            key = m.group(1)
            out.append(f"{key}={border_desired[key]}")
            seen_border.add(key)
            continue
        out.append(line)
    else:
        out.append(line)

if current == "colors":
    for k, v in desired.items():
        if k not in seen_colors:
            out.append(f"{k}={v}")
elif current == "border":
    for k, v in border_desired.items():
        if k not in seen_border:
            out.append(f"{k}={v}")

if not seen_colors.issuperset(desired.keys()):
    try:
        idx = next(i for i, l in enumerate(out) if l.strip() == "[colors]")
        insert_at = idx + 1
        for k, v in desired.items():
            if k not in seen_colors:
                out.insert(insert_at, f"{k}={v}")
                insert_at += 1
    except StopIteration:
        pass

p.write_text("\n".join(out) + "\n")
print("Fuzzel sincronizado (translúcido e6) con pywal.")
PYEOF
fi

echo "Sincronización completada (Foot + Fuzzel desde pywal)."
