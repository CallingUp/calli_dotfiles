# Contextual Waybar

The normal `neon` bar is preserved unchanged.  The contextual set uses a single
centered bar and has no pointer-hover actions.

| Profile | Contents | Shortcut |
| --- | --- | --- |
| Media | player, spectrum, previous/next | `Mod+Ctrl+M` |
| System | CPU, RAM, temperature, battery, network | `Mod+Ctrl+I` |
| Actions | launcher, control center, notifications, audio, brightness, session | `Mod+Ctrl+P` |

`Mod+Ctrl+Space` cycles the three profiles. The leading icon in each profile
also cycles it by click. `scripts/bin/waybar_manager.sh` changes only the
`~/.config/waybar/config` and `style.css` symlinks, then restarts the existing
user service when it owns Waybar. To return to the full old bar, run
`waybar_manager.sh --select` and choose `neon`.
