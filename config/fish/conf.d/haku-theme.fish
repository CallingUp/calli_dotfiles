set -l haku_colors "$HOME/.local/state/haku_theme/colors.css"
set -l haku_accent 9094ba
set -l haku_active 999DC2
set -l haku_inactive 41445E

if test -r "$haku_colors"
    set -l accent_line (string match -r '@define-color accent_color #[0-9A-Fa-f]{6}' < "$haku_colors")
    set -l active_line (string match -r '@define-color accent_active #[0-9A-Fa-f]{6}' < "$haku_colors")
    set -l inactive_line (string match -r '@define-color accent_inactive #[0-9A-Fa-f]{6}' < "$haku_colors")

    test -n "$accent_line"; and set haku_accent (string replace -r '.*#' '' "$accent_line")
    test -n "$active_line"; and set haku_active (string replace -r '.*#' '' "$active_line")
    test -n "$inactive_line"; and set haku_inactive (string replace -r '.*#' '' "$inactive_line")
end

set -g pure_color_primary $haku_accent
set -g pure_color_current_directory $haku_accent
set -g pure_color_success $haku_accent
set -g pure_color_prompt_on_success $haku_accent
set -g pure_color_info $haku_active
set -g pure_color_git_unpulled_commits $haku_active
set -g pure_color_git_unpushed_commits $haku_active
set -g pure_color_git_branch $haku_inactive
set -g pure_color_git_dirty d2768c
set -g pure_color_git_stash $haku_active
set -g pure_color_mute 62647c
set -g pure_color_warning c7aa78
set -g pure_color_danger d2768c
set -g pure_color_command_duration 62647c
set -g pure_symbol_prompt '❯'
set -g pure_symbol_git_dirty '•'
set -g pure_threshold_command_duration 3

set -g fish_color_normal d8daea
set -g fish_color_command $haku_accent --bold
set -g fish_color_keyword $haku_active
set -g fish_color_param b9bbce
set -g fish_color_quote 83b6af
set -g fish_color_redirection aa8fba
set -g fish_color_end $haku_active
set -g fish_color_option a9acd0
set -g fish_color_comment 62647c --italic
set -g fish_color_error d2768c --bold
set -g fish_color_operator $haku_active
set -g fish_color_escape c7aa78
set -g fish_color_autosuggestion 62647c
set -g fish_color_selection --background=$haku_inactive d8daea
set -g fish_color_search_match --background=$haku_inactive $haku_active
set -g fish_color_cwd $haku_accent
set -g fish_color_cwd_root d2768c
set -g fish_pager_color_prefix $haku_accent --bold
set -g fish_pager_color_selected_background --background=$haku_inactive
