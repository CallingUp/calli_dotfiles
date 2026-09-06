function fish_prompt
    set -l last_status $status
    set -l accent $pure_color_primary
    set -l accent_dark $pure_color_git_branch
    set -l text d8daea
    set -l muted 62647c
    set -l danger d2768c

    set -l haku_colors "$HOME/.local/state/haku_theme/colors.css"
    if test -r "$haku_colors"
        set -l accent_line (string match -r '@define-color accent_color #[0-9A-Fa-f]{6}' < "$haku_colors")
        set -l inactive_line (string match -r '@define-color accent_inactive #[0-9A-Fa-f]{6}' < "$haku_colors")

        test -n "$accent_line"; and set accent (string replace -r '.*#' '' "$accent_line")
        test -n "$inactive_line"; and set accent_dark (string replace -r '.*#' '' "$inactive_line")

        set -g pure_color_primary $accent
        set -g pure_color_current_directory $accent
        set -g pure_color_success $accent
        set -g pure_color_prompt_on_success $accent
        set -g pure_color_git_branch $accent_dark
        set -g fish_color_command $accent --bold
        set -g fish_color_selection --background=$accent_dark $text
        set -g fish_color_search_match --background=$accent_dark $accent
        set -g fish_color_cwd $accent
        set -g fish_pager_color_prefix $accent --bold
        set -g fish_pager_color_selected_background --background=$accent_dark
    end

    set -l location (prompt_pwd --full-length-dirs 2)

    set_color $accent
    printf '╭─'
    set_color --background=$accent 000000 --bold
    printf '  %s ' $USER
    set_color normal
    set_color $accent
    printf ' '

    set_color $accent_dark
    printf ''
    set_color --background=$accent_dark $text --bold
    printf ' 󰉋 %s ' $location
    set_color normal
    set_color $accent_dark
    printf ''

    set -l git_info (fish_vcs_prompt)
    if test -n "$git_info"
        printf ' '
        set_color $accent_dark
        printf ''
        set_color --background=$accent_dark $accent
        printf ' 󰊢 %s ' (string trim $git_info)
        set_color normal
        set_color $accent_dark
        printf ''
    end

    if test $CMD_DURATION -ge 2000
        set_color $muted
        printf '  󱎫 %s' (string escape -- (math -s1 "$CMD_DURATION / 1000"))s
    end

    printf '\n'
    if test $last_status -eq 0
        set_color $accent --bold
        printf '╰─❯ '
    else
        set_color $danger --bold
        printf '╰─󰅙 %s ❯ ' $last_status
    end
    set_color normal
end
