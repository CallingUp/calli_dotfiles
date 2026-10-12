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
- Tray icons expand into a themed application menu on the right.
- Accent follows ~/.local/state/haku_theme/colors.css.
- Lock and logout actions call lock.sh and Niri, respectively.
- Settings/theme caches use ~/.cache/haku-minflair-niri.
- Startup does not apply Minflair's cursor, desktop font or power profile.
- The Niri entry point enables Minflair's native notification server. Noctalia's
  `[notification] enable_daemon = false` prevents a competing server. Mako was
  stopped (already disabled), not uninstalled. Notifications expand the central
  island; right-click the idle clock for history and DND.
  The previous live Noctalia configuration is backed up at
  `~/.config/noctalia/config.toml.before-minflair-notifications`.

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

Mod+Left/Right cycle idle clock → stats → control center → power actions.
Media remains independent of this cycle.
Mod+Up hides the bar; Mod+Down shows it without restarting the service.
These bindings reuse haku-waybar-visibility; the live Niri binding file was
updated as well as the repository copy.

Fullscreen state comes from Wayland ToplevelManager, not a nonexistent
is_fullscreen field in this Niri version's focused-window JSON.
Workspace updates use Niri event-stream with a three-second recovery poll.

## Compact information

The central stats island displays CPU usage, memory percentage and temperature
with Nerd Font icons, reusing SystemStats. It has the same 32px height as the
idle clock. The former left GitHub/dashboard capsule is hidden.

The right island keeps the original Minflair compact player: album thumbnail
and four Cava bands, without artist/title text. While paused it shrinks to the
thumbnail; clicking opens the full player with the upstream morph animation.
Cava uses 30fps and bucket averages instead of peak-biased aggregation;
capture stops when paused, hidden or fullscreen.

## Niri quick controls

Night light uses the installed `gammastep -m wayland -O <temperature>`, owned
by the shell process rather than globally killing other gamma tools.
Game mode changes only the power profile, restoring the previous value on
disable; it never changes Niri effects, scanout or animation settings. Busy
operations disable the game-mode tile, and subprocess errors are surfaced.
Caffeine preserves the user's prior state around game mode. It uses both a
logind idle inhibitor and a native Wayland IdleInhibitor on a separate 1px
transparent, input-free background surface, independent of bar visibility.
Live smoke test: caffeine enabled for one second, logind reported the
`quickshell / Keep screen active / idle / block` inhibitor, and the dedicated
Wayland surface became visible with no errors. The original disabled state was
restored in a finally block. No hypridle/swayidle process was running at the
time of inspection; an actual screen timeout remains untested.
Battery limit hardware status is readable; writes remain user-initiated and
failed/canceled authorization no longer reports success.

Read-only control diagnostics:
`quickshell ipc -p /home/calli/haku_shell/config/quickshell/minflair-niri/niri-preview.qml call haku-controls status`.
`haku-controls setCaffeine true|false` provides the same explicit toggle as the
tile for testing and scripting.

## Launcher and hardware keys

Mod+Tab / Mod+Shift+Tab now use Niri's built-in recent-windows switcher, with
real compositor-rendered previews. The temporary title-only Quickshell
WindowSwitcher component is no longer instantiated. `recent-windows.kdl`
sets an explicit Mod-only binding list (replacing native Alt/Mod defaults),
80ms open delay, 12px highlight padding, 14px highlight radius and preview
limits of 280px height / 0.35 scale. `accent.kdl` supplies highlight color;
the live and repository set-wallpaper generators maintain it dynamically.
Niri validation passed. Existing overview and Noctalia lock are unchanged.
Exact Quickshell list layout/background/font cannot be reproduced through
these native configuration options; that would require renderer changes.

Transition polish: island opening/closing uses shared 280/160ms durations;
central shape changes use 220ms and panel content fades 60/140ms, scaled by
the existing durationFactor/reduced-animation setting. Bar hide timing is
unchanged. The earlier Quickshell switcher animation is now inactive;
native recent-windows-close uses the existing Niri animation configuration.
No continuous animation or polling was added.

Mod+Enter opens the Quickshell launcher, using native DesktopEntries and usage
ranking persisted to `$XDG_STATE_HOME/haku-launcher-usage.json` (default
`~/.local/state`). Mod+Z toggles the Quickshell control center. Its audio section
uses PipeWire for output/input selection, volume and microphone mute. Wi-Fi
status/cached networks and Bluetooth status were checked without changing the
connection or pairings. New personal secured Wi-Fi networks request their
password inside the Wi-Fi page (Enter or Connect), with a reveal toggle.
Adapted from local Noctalia NetworkTab and NetworkManagerService: secrets travel
over stdin then D-Bus AddAndActivateConnection2, never command-line arguments.
New profiles use persist=memory, with WPA-PSK/SAE chosen from AP RSN flags.
Failed attempts remove only their newly created connection object.
Enterprise authentication and a full NetworkManager secret agent are not implemented.
The field clears on submit/close; connection errors remain in the page.
New Bluetooth pairings use `scripts/bluetooth_pair.py`, an application-scoped
BlueZ Agent1 (KeyboardDisplay) that runs only for a selected pairing. PIN input,
numeric confirmation, remote code display and service authorization stay in
the Bluetooth page. No default-agent takeover or automatic trust is performed.
Closing the page/surface cancels pairing; a 75-second safety timer also cancels.
Replies use stdin; JSON events use stdout. Mock tests cover numeric validation,
confirmation, rejection and device isolation, without registering a real agent.
Actual hardware pairing still needs a user-selected device test.
Saved connections use the panel actions
with bounded waits and error reporting. Actual connection/pairing changes need
testing with a user-selected device/network. Other upstream controls remain
outside this validation.

Niri's five hardware bindings call `~/.local/bin/haku-osd-control` (symlink to
`scripts/bin/haku-osd-control`). Volume uses wpctl in 5% steps, capped at 100%;
brightness uses brightnessctl's backlight class in 5% steps. Controls do not
depend on Noctalia. A short Quickshell IPC call displays a transient island OSD
with percentage and progress bar; repeated updates replace the active OSD and
do not enter notification history. No background polling was added.
