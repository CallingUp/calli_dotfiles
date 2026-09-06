#!/usr/bin/env bash

CFG="$HOME/.config/niri/input.kdl"

if grep -q 'layout "latam"' "$CFG"; then
    sed -i 's/layout "latam"/layout "us"/' "$CFG"
    layout="US"
else
    sed -i 's/layout "us"/layout "latam"/' "$CFG"
    layout="LATAM"
fi

niri msg action load-config-file

notify-send \
    "Keyboard Layout" \
    "$layout"
