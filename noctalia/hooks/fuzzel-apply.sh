#!/usr/bin/env bash
# post_hook del user-template fuzzel: asegura include del tema noctalia en fuzzel.ini.
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
config_file="$config_dir/fuzzel/fuzzel.ini"

if [[ "$config_dir" == "$HOME"/* ]]; then
    include_path="~/fuzzel/themes/noctalia"
else
    include_path="$config_dir/fuzzel/themes/noctalia"
fi
include_line="include=$include_path"

mkdir -p "$(dirname "$config_file")"

if [ ! -f "$config_file" ]; then
    printf '%s\n' "$include_line" > "$config_file"
elif ! grep -q 'include.*noctalia' "$config_file"; then
    tmp_file="$(mktemp "${config_file}.tmp.XXXXXX")"
    trap 'rm -f "$tmp_file"' EXIT
    sed '/include=.*themes/d' "$config_file" > "$tmp_file"
    { printf '%s\n' "$include_line"; cat "$tmp_file"; } > "${tmp_file}.new"
    mv "${tmp_file}.new" "$tmp_file"
    trap - EXIT
    if ! cmp -s "$config_file" "$tmp_file"; then
        cat "$tmp_file" > "$config_file"
    fi
    rm -f "$tmp_file"
fi
