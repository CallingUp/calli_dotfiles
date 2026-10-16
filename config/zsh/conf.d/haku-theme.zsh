typeset -g HAKU_ACCENT='B99573'
typeset -g HAKU_ACTIVE='D7B894'
typeset -g HAKU_INACTIVE='705542'
typeset -g HAKU_TEXT='E8DCC8'
typeset -g HAKU_MUTED='967F6B'
typeset -g HAKU_DANGER='BF616A'
typeset -g HAKU_WARNING='D7B894'

haku_load_colors() {
    local colors="$HOME/.config/haku/palette.conf"
    local line key value
    local pattern='^([A-Z_]+)="(#[[:xdigit:]]{6})"$'
    local -A names=(ACCENT HAKU_ACCENT ACTIVE HAKU_ACTIVE INACTIVE HAKU_INACTIVE FOREGROUND HAKU_TEXT MUTED HAKU_MUTED ERROR HAKU_DANGER WARNING HAKU_WARNING)
    if [[ -r "$colors" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ "$pattern" ]]; then
                key="$match[1]"
                value="$match[2]"
                [[ -n "${names[$key]:-}" ]] && typeset -g "${names[$key]}=${value#\#}"
            fi
        done < "$colors"
    fi

    export HAKU_ACCENT HAKU_ACTIVE HAKU_INACTIVE HAKU_TEXT HAKU_MUTED HAKU_DANGER HAKU_WARNING
}

haku_apply_syntax_colors() {
    typeset -gA ZSH_HIGHLIGHT_STYLES

    ZSH_HIGHLIGHT_STYLES[default]="fg=#$HAKU_TEXT"
    ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=#$HAKU_DANGER,bold"
    ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=#$HAKU_ACTIVE"
    ZSH_HIGHLIGHT_STYLES[suffix-alias]="fg=#$HAKU_ACCENT,bold"
    ZSH_HIGHLIGHT_STYLES[global-alias]="fg=#$HAKU_ACCENT,bold"
    ZSH_HIGHLIGHT_STYLES[precommand]="fg=#$HAKU_ACTIVE"
    ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=#$HAKU_ACTIVE"
    ZSH_HIGHLIGHT_STYLES[autodirectory]="fg=#$HAKU_ACCENT,bold"
    ZSH_HIGHLIGHT_STYLES[path]="fg=#$HAKU_TEXT"
    ZSH_HIGHLIGHT_STYLES[path_pathseparator]="fg=#$HAKU_ACTIVE"
    ZSH_HIGHLIGHT_STYLES[globbing]="fg=#$HAKU_ACTIVE"
    ZSH_HIGHLIGHT_STYLES[history-expansion]="fg=#$HAKU_ACTIVE"
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=#$HAKU_ACTIVE"
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=#$HAKU_ACTIVE"
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=#$HAKU_ACCENT"
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=#$HAKU_ACCENT"
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]="fg=#$HAKU_ACCENT"
    ZSH_HIGHLIGHT_STYLES[redirection]="fg=#$HAKU_ACTIVE"
    ZSH_HIGHLIGHT_STYLES[comment]="fg=#$HAKU_MUTED,italic"
}

haku_load_colors
haku_apply_syntax_colors
