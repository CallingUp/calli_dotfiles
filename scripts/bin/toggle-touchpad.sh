#!/usr/bin/env bash

set -e

CFG="$HOME/.config/niri/input.kdl"
MARKER="TOGGLE_TOUCHPAD_OFF"

if grep -q "off // $MARKER" "$CFG"; then
    # Activar touchpad
    sed -i "/off \\/\\/ $MARKER/d" "$CFG"

    niri msg action load-config-file

    notify-send \
        "Touchpad" \
        "Activado" \
        -i input-touchpad
else
    # Desactivar touchpad
    sed -i \
        "/^[[:space:]]*touchpad[[:space:]]*{/a\\        off // $MARKER" \
        "$CFG"

    niri msg action load-config-file

    notify-send \
        "Touchpad" \
        "Desactivado" \
        -i input-touchpad
fi
