#!/usr/bin/env bash

set -euo pipefail

pgrep -x hyprlock >/dev/null && exit 0
exec hyprlock --config "$HOME/.config/hypr/hyprlock.conf" --immediate-render
