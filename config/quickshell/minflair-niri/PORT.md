# Minflair → Niri

Upstream: https://github.com/t4lentles5/minflair
Imported revision: a5d8a4455d80fbac71f270d5aec5cff6e0159066
Original code is distributed under GPL-3.0; see LICENSE.

The complete upstream Quickshell tree is included. The Niri entry point is
`niri-preview.qml`, used by haku-quickshell.service. The upstream `shell.qml`
is preserved for comparison; do not launch that Hyprland entry point on Niri.

The active dynamic island uses upstream IslandBar, all three IslandPill
components, IslandComponents, original widgets, layout and morph animations.
This is not the earlier HakuIslandPill approximation.

Niri integration:

- HyprlandService keeps its upstream API name but now reads Niri workspaces
  and focused-window state, and dispatches Niri workspace actions.
- Workspace dots use that backend. Fullscreen hides the entire surface.
- Outside clicks close the island; the idle input region is restricted to
  visible bar elements, not the full top of the screen.
- Haku show/hide and media IPC remain available.
- Tray icons and native application menus remain on the right.
- Accent follows ~/.local/state/haku_theme/colors.css.
- Lock and logout actions call lock.sh and Niri, respectively.
- Settings/theme caches use ~/.cache/haku-minflair-niri.
- Startup does not apply Minflair's cursor, desktop font or power profile.
- Noctalia remains the notification server. Minflair's native notification
  server is opt-in, disabled by default.

Scope: the bar and its island panels are enabled, not a second desktop shell
or lock screen. Other upstream layouts, settings and scripts are included as
source but are not a complete Niri desktop port. In particular, upstream
Hyprland compositor settings are not supported by the compatibility backend.

Previous bar backup:
~/.local/state/haku-backups/minflair-before-port/haku-media-island
Previous bar source is also retained at ../haku-media-island.

## Attached islands and navigation

Islands now start at y=0 with square top corners and rounded bottom corners.
Expansion preserves that attachment instead of translating the card down.
Panel changes close the old content before opening the most recent request,
so rapid key presses do not accumulate a queue.

Mod+Left/Right cycle music → control center → power actions.
Mod+Up hides the bar; Mod+Down shows it without restarting the service.
These bindings reuse haku-waybar-visibility; the live Niri binding file was
updated as well as the repository copy.

Fullscreen state comes from Wayland ToplevelManager, not a nonexistent
is_fullscreen field in this Niri version's focused-window JSON.
Workspace updates use Niri event-stream with a three-second recovery poll.

## Compact information

The left island displays CPU usage, memory percentage, CPU temperature,
output volume/mute, and brightness. CPU/RAM/temperature reuse SystemStats;
volume uses PipeWire notifications, and brightness is queried every 2s.

The right island uses artist :: title, capped at 300px of text, plus a separate
12-band stereo Cava area. It has no album/music icon or playback buttons in
the compact state. Its width follows the text and retains the upstream morph.
Cava uses 30fps and bucket averages instead of peak-biased aggregation;
capture stops when paused, hidden or fullscreen.
