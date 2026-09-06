# ============================================================
# Niri
# ============================================================

#microfono

alias mic='pactl set-source-port alsa_input.pci=0000_00_1f.3.analog-stereo analog-input-headset-mic'

#cpu-power
alias cpui='sudo cpupower frequency-info'

alias cpu28='sudo cpupower frequency-set --max 2800000'
alias cpu30='sudo cpupower frequency-set --max 3000000'

# Guía de configuración
alias g='cat ~/.config/fish/textoxd'
alias ge='nano ~/.config/fish/textoxd'
alias sc='cat ~/.config/fish/shortcuts'
alias sce='nano ~/.config/fish/shortcuts'
alias cursor='cursor-theme'

#SSH???
alias sshjuan='ssh admsupport@179.197.74.30'

# Config raíz
alias nc-root='nano ~/.config/niri/config.kdl'

#android studio
alias as='/opt/android-studio/bin/studio.sh'


# Módulos
alias nc-auto='nano ~/.config/niri/autostart.kdl'
alias nc-env='nano ~/.config/niri/environment.kdl'
alias nc-in='nano ~/.config/niri/input.kdl'
alias nc-out='nano ~/.config/niri/output.kdl'
alias nc-ly='nano ~/.config/niri/layout.kdl'
alias nc-ky='nano ~/.config/niri/keybinds.kdl'
alias nc-wr='nano ~/.config/niri/rules.kdl'
alias nc-fx='nano ~/.config/niri/effects.kdl'
alias nc-ac='nano ~/.config/niri/accent.kdl'
alias shellmode='haku-shell-profile'

# Validar / recargar
alias nv='niri validate'
alias nr='niri msg action load-config-file'

# ============================================================
# Shell visual
# ============================================================

alias waybarconfig='nano ~/.config/waybar/neon/config'
alias waybarstyle='nano ~/.config/waybar/neon/style.css'
alias waybarmodules='cd ~/.config/waybar/module'
alias kittyconfig='nano ~/.config/kitty/kitty.conf'
alias roficonfig='nano ~/.config/rofi/config.rasi'
alias roficlipboard='nano ~/.config/rofi/clipboard.rasi'
alias noctaliaconfig='nano ~/.config/noctalia/config.toml'
alias awwwconfig='nano ~/.config/awww/config.toml'
alias cavaconfig='nano ~/.config/cava/config'
alias fetchconfig='nano ~/.config/fastfetch/config.jsonc'

# ============================================================
# Fish
# ============================================================

alias fc='nano ~/.config/fish/config.fish'

function sf
    source ~/.config/fish/conf.d/haku-theme.fish
    source ~/.config/fish/config.fish
    functions --erase fish_prompt
    source ~/.config/fish/functions/fish_prompt.fish
end

function f
    haku-font $argv
end

function ytme
    nano ~/.config/haku/pear-overlay.template.css
    haku-pear-theme
end

# Fastfetch
function fastfetch
    set -l width $COLUMNS
    test -n "$width"; or set width 80

    if test $width -lt 64
        command fastfetch --config ~/.config/fastfetch/config-minimal.jsonc $argv
    else if test $width -lt 110
        command fastfetch --config ~/.config/fastfetch/config-compact.jsonc $argv
    else
        command fastfetch --config ~/.config/fastfetch/config.jsonc --key-padding-left 6 $argv
    end
end

# ~/.local/bin
fish_add_path ~/.local/bin

# ============================================================
# Wallpapers
# ============================================================

function sw
    set img (find /home/calli/Pictures/Wallpapers/ -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" \) -printf "%f\n" | fzf --preview "kitten icat --clear --transfer-mode=memory --place=\$FZF_PREVIEW_COLUMNSx\$FZF_PREVIEW_LINES@0x0 /home/calli/Pictures/Wallpapers/{} 2>/dev/null" --preview-window=right:60%)

    if test -n "$img"
        set wallpaper_path "/home/calli/Pictures/Wallpapers/$img"
        set-wallpaper "$wallpaper_path"
    end
end

function swr
    set wallpaper_root /home/calli/Pictures/Wallpapers
    set exit_item "← Salir"

    while true
        set img (begin
            find "$wallpaper_root" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" \) -printf "%P\n"
            echo "$exit_item"
        end | fzf --prompt="Eliminar fondo › " --header="Enter enviar a la Papelera · Esc o Salir para cerrar" --preview "kitten icat --clear --transfer-mode=memory --place=\$FZF_PREVIEW_COLUMNSx\$FZF_PREVIEW_LINES@0x0 $wallpaper_root/{} 2>/dev/null" --preview-window=right:60%)

        if test -z "$img"; or test "$img" = "$exit_item"
            break
        end

        set wallpaper_path "$wallpaper_root/$img"
        if test -f "$wallpaper_path"
            gio trash "$wallpaper_path"
        end
    end
end
