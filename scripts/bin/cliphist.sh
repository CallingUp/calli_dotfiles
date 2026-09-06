#!/usr/bin/env bash

while true; do
    clear_entry="Borrar todo el historial"

    selection="$(
        {
            printf '%s\n' "$clear_entry"
            cliphist list
        } |
            rofi -dmenu \
                -i \
                -p "󰅌" \
                -theme "$HOME/.config/rofi/clipboard.rasi" \
                -kb-custom-1 "Alt+Delete"
    )"

    rofi_exit=$?

    [ -z "$selection" ] && exit 0

    #
    if [ "$selection" = "$clear_entry" ]; then
        confirm="$(
            printf '%s\n%s\n' \
                "Cancelar" \
                "󰆴  Borrar todo" |
                rofi -dmenu \
                    -p "¿Borrar todo el historial?" \
                    -theme "$HOME/.config/rofi/clipboard.rasi" \
                    -theme-str "window { width: 26%; } listview { lines: 2; }"
        )"

        if [ "$confirm" = "󰆴  Borrar todo" ]; then
            cliphist wipe
            notify-send "Clipboard" "Historial eliminado" -t 1500
        fi

        continue
    fi

    #
    if [ "$rofi_exit" -eq 10 ]; then
        printf '%s\n' "$selection" |
            cliphist delete

        notify-send \
            "Clipboard" \
            "Clip eliminado" \
            -t 1200

        continue
    fi

    #
    if [ "$rofi_exit" -eq 0 ]; then
        printf '%s\n' "$selection" |
            cliphist decode |
            wl-copy

        exit 0
    fi

    exit 0
done
