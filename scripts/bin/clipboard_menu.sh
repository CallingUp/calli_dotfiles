#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--wipe" || "${1:-}" == "--clear" ]]; then
    cliphist wipe
    notify-send "Clipboard" "Historial eliminado" -t 2000
    exit 0
fi
exec python3 "$HOME/haku_shell/scripts/bin/haku-clipboard"
