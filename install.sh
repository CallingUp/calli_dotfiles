#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apply=false

if [[ "${1:-}" == "--apply" ]]; then
    apply=true
elif [[ $# -ne 0 ]]; then
    printf 'Uso: %s [--apply]\n' "$0" >&2
    exit 2
fi

items=(niri noctalia kitty fish rofi fastfetch font hypr)

if ! "$apply"; then
    printf 'Se restaurarán: %s y Waybar Neon.\n' "${items[*]}"
    printf 'También se copiarán scripts a ~/.local/bin y se creará un respaldo previo.\n'
    printf 'Ejecuta %s --apply para continuar.\n' "$0"
    exit 0
fi

backup_dir="$HOME/backups/haku-shell-install-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir/config" "$backup_dir/bin"

for item in "${items[@]}"; do
    source="$repo_dir/config/$item"
    target="$HOME/.config/$item"
    [[ -d "$target" ]] && cp -a "$target" "$backup_dir/config/"
    mkdir -p "$target"
    cp -a "$source/." "$target/"
done

waybar_target="$HOME/.config/waybar"
[[ -d "$waybar_target" ]] && cp -a "$waybar_target" "$backup_dir/config/"
mkdir -p "$waybar_target"
cp -a "$repo_dir/config/waybar/neon" "$waybar_target/"
ln -sfn "$waybar_target/neon/config" "$waybar_target/config"
ln -sfn "$waybar_target/neon/style.css" "$waybar_target/style.css"

[[ -d "$HOME/.local/bin" ]] && cp -a "$HOME/.local/bin/." "$backup_dir/bin/"
mkdir -p "$HOME/.local/bin"
for source in "$repo_dir/scripts/bin/"*; do
    name="${source##*/}"
    case "$name" in
        codex|haku-ssh-unlock|import-ficon-codex-sessions|install-extra-data-mount|merge-helium-popos|repartition-pop-disk)
            continue
            ;;
    esac
    cp -a "$source" "$HOME/.local/bin/"
done

printf 'Restauración terminada. Respaldo: %s\n' "$backup_dir"
