#!/usr/bin/env bash

# Manage Waybar modes via symlinks, Rofi selection, and mode cycling.

# Include WAYBAR_MODE_USER
[ -f "$HOME/hakuspace-control/main_setting.sh" ] && source "$HOME/hakuspace-control/main_setting.sh"

WAYBAR_DIR="$HOME/.config/waybar"
USER_WAYBAR_DIR="$HOME/hakuspace-control/waybar"
STATE_FILE="$HOME/.local/state/haku_theme/waybar_current_mode"
CURRENT_STATE="top"
WAYBAR_MODES_DEAULT=("top" "neon" "island" "coredge" "full" "minimal" "left")

# WAYBAR_MODES_DEAULT + WAYBAR_MODE_USER
WAYBAR_MODES=("${WAYBAR_MODES_DEAULT[@]}" "${WAYBAR_MODE_USER[@]}")
CONTEXT_MODES=("context-media" "context-system" "context-actions")

# Init state file if missing
if [[ -f "$STATE_FILE" ]]; then
    CURRENT_STATE=$(cat "$STATE_FILE")
else
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "top" > "$STATE_FILE"
fi

# Link selected mode files to main config directory
link_mode() {
    local mode="$1"
    local target_dir=""

    if [[ "$mode" == context-* ]] && [[ -d "$WAYBAR_DIR/contextual" ]]; then
        target_dir="$WAYBAR_DIR/contextual"
    elif [[ -d "$WAYBAR_DIR/$mode" ]]; then
        target_dir="$WAYBAR_DIR/$mode"
    elif [[ -d "$USER_WAYBAR_DIR/$mode" ]]; then
        target_dir="$USER_WAYBAR_DIR/$mode"
    else
        notify-send "Waybar Error" "Mode directory not found: $mode"
        exit 1
    fi

    ln -sf "$target_dir/config" "$WAYBAR_DIR/config"
    ln -sf "$target_dir/style.css" "$WAYBAR_DIR/style.css"
    echo "$mode" > "$STATE_FILE"
    CURRENT_STATE="$mode"
}
# Start or restart Waybar
restart_waybar() {
    if [[ "$XDG_CURRENT_DESKTOP" == "niri" ]]; then
        if grep -q "1" /tmp/cava_underbar_status 2>/dev/null; then
            $HOME/.local/bin/cava_manager.sh --toggle
        fi
    fi

    # When the packaged user service owns Waybar, restart it there. Killing its
    # process and starting a detached replacement races systemd and can create
    # two bars.
    if systemctl --user is-active --quiet waybar.service 2>/dev/null; then
        systemctl --user restart waybar.service
        return
    fi

    if pgrep -fx waybar >/dev/null; then
        pkill -fx waybar
        sleep 0.2
    fi

    waybar &
}

# Contextual Haku bar: one centered visual bar, with three intentionally small
# profiles.  The selected profile remains a normal Waybar mode, so the original
# modes (neon, top, minimal, ...) are never altered.
select_context_mode() {
    local requested="$1"
    local selected=""

    case "$requested" in
        next)
            local index=0
            for i in "${!CONTEXT_MODES[@]}"; do
                if [[ "${CONTEXT_MODES[$i]}" == "$CURRENT_STATE" ]]; then
                    index=$(( (i + 1) % ${#CONTEXT_MODES[@]} ))
                    selected="${CONTEXT_MODES[$index]}"
                    break
                fi
            done
            [[ -n "$selected" ]] || selected="${CONTEXT_MODES[0]}"
            ;;
        prev)
            local index=0
            for i in "${!CONTEXT_MODES[@]}"; do
                if [[ "${CONTEXT_MODES[$i]}" == "$CURRENT_STATE" ]]; then
                    index=$(( (i - 1 + ${#CONTEXT_MODES[@]}) % ${#CONTEXT_MODES[@]} ))
                    selected="${CONTEXT_MODES[$index]}"
                    break
                fi
            done
            [[ -n "$selected" ]] || selected="${CONTEXT_MODES[0]}"
            ;;
        media) selected="context-media" ;;
        system) selected="context-system" ;;
        actions) selected="context-actions" ;;
        *)
            notify-send "Waybar" "Perfil contextual desconocido: $requested"
            exit 2
            ;;
    esac

    # A panel opened for the old profile must never survive into the next one:
    # otherwise, for example, Media remains open after switching to System.
    close_context_panel() {
        local hover_dir="/tmp/haku-panel-hover-$UID"
        local active_panel=""
        [[ -f "$hover_dir/active" ]] && active_panel=$(<"$hover_dir/active")
        [[ -n "$active_panel" ]] && noctalia msg panel-close "$active_panel" >/dev/null 2>&1 || true
        rm -f "$hover_dir/active" "$hover_dir/opened" "$hover_dir/waybar" "$hover_dir/panel"
    }

    # The contextual configuration stays loaded. Only the state file changes;
    # SIGRTMIN+8 lets its three Gtk::Revealers animate without a Waybar reload.
    if [[ "$(readlink -f "$WAYBAR_DIR/config" 2>/dev/null)" != "$WAYBAR_DIR/contextual/config" ]]; then
        close_context_panel
        link_mode "$selected"
        restart_waybar
    elif [[ "$selected" != "$CURRENT_STATE" ]]; then
        close_context_panel
        printf '%s\n' "$selected" > "$STATE_FILE"
        CURRENT_STATE="$selected"
        pkill -RTMIN+8 -x waybar 2>/dev/null || true
    fi
}

case "$1" in
    --context-next) select_context_mode next; exit 0 ;;
    --context-prev) select_context_mode prev; exit 0 ;;
    --context-media) select_context_mode media; exit 0 ;;
    --context-system) select_context_mode system; exit 0 ;;
    --context-actions) select_context_mode actions; exit 0 ;;
esac

# Handle --cycle argument to toggle through the MODES array
if [[ "$1" == "--cycle" ]]; then
    current_idx=-1
    for i in "${!WAYBAR_MODES[@]}"; do
        if [[ "${WAYBAR_MODES[$i]}" == "$CURRENT_STATE" ]]; then
            current_idx=$i
            break
        fi
    done

    # Calculate next mode index (if current not found, fallback to 0 which is "top")
    next_idx=$(( (current_idx + 1) % ${#WAYBAR_MODES[@]} ))
    next_mode="${WAYBAR_MODES[$next_idx]}"

    if [[ "$next_mode" != "$CURRENT_STATE" ]]; then
        link_mode "$next_mode"
        restart_waybar
    fi
    exit 0
fi

# Handle --select argument via Rofi
if [[ "$1" == "--select" ]]; then
    choice=$(printf "%s\n" "${WAYBAR_MODES[@]}" | rofi -dmenu -p "Waybar" -i -theme-str 'window {width: 25%; height: 40%;} entry { placeholder: " Select Mode"; }')
    [[ -z "$choice" ]] && exit 0

    if [[ "$choice" != "$CURRENT_STATE" ]]; then
        link_mode "$choice"
        restart_waybar
    fi
    exit 0
fi

# Ensure symlinks exist
if [[ ! -f "$WAYBAR_DIR/config" ]] || [[ ! -f "$WAYBAR_DIR/style.css" ]]; then
    link_mode "$CURRENT_STATE"
fi

# Auto-start Waybar if not running
if ! pgrep -x waybar >/dev/null; then
    waybar &
fi
