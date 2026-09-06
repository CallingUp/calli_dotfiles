#!/usr/bin/env bash

LOCK="󰌾  Lock"
LOGOUT="󰍃  Logout"
SUSPEND="󰤄  Suspend"
REBOOT="󰜉  Reboot"
SHUTDOWN="󰐥  Shutdown"
CANCEL="󰜺  Cancel"

choice="$(
    printf '%s\n' \
        "$LOCK" \
        "$LOGOUT" \
        "$SUSPEND" \
        "$REBOOT" \
        "$SHUTDOWN" \
        "$CANCEL" |
        rofi -dmenu \
            -i \
            -p "Session"
)"

case "$choice" in
    "$LOCK")
        loginctl lock-session
        ;;

    "$LOGOUT")
        niri msg action quit
        ;;

    "$SUSPEND")
        systemctl suspend
        ;;

    "$REBOOT")
        systemctl reboot
        ;;

    "$SHUTDOWN")
        systemctl poweroff
        ;;

    *)
        exit 0
        ;;
esac

