#!/usr/bin/env bash

#
if [ "$1" = "--wipe" ]; then
    cliphist wipe
    notify-send "Clipboard" "Historial eliminado" -t 2000
    exit 0
fi

#
if ! pgrep -x "wl-paste" >/dev/null; then
    wl-paste --type text --watch cliphist store &
    wl-paste --type image --watch cliphist store &
fi

#
clear_entry="󰆴  Borrar todo el historial"

result=$(
    {
        printf '%s\n' "$clear_entry"
        cliphist list
    } | rofi -dmenu \
        -p "󰅌 Clipboard" \
        -kb-custom-1 "Alt+Delete" \
        -theme-str "window { width: 50%; } listview { lines: 10; }"
)

exit_code=$?

[ -z "$result" ] && exit 0

#
if [ "$result" = "$clear_entry" ]; then
    confirm=$(
        printf '%s\n%s\n' "Cancelar" "Borrar todo" |
            rofi -dmenu \
                -p "¿Borrar historial?" \
                -theme-str "window { width: 25%; } listview { lines: 2; }"
    )

    if [ "$confirm" = "Borrar todo" ]; then
        cliphist wipe
        notify-send "Clipboard" "Historial eliminado" -t 2000
    fi

    exit 0
fi

#
if [ "$exit_code" -eq 10 ]; then
    printf '%s\n' "$result" | cliphist delete
    notify-send "Clipboard" "Clip eliminado" -t 1500

    exec "$0"
fi

#
if [ "$exit_code" -eq 0 ]; then
    printf '%s\n' "$result" |
        cliphist decode |
        wl-copy

    notify-send "Clipboard" "Copiado al portapapeles" -t 1500
fi
