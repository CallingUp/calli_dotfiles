# Minflair → Niri

[Documentación](../../../docs/README.md) · [Instalación](../../../docs/INSTALL.md)

Upstream: https://github.com/t4lentles5/minflair
Imported revision: a5d8a4455d80fbac71f270d5aec5cff6e0159066
Original code is distributed under GPL-3.0; see LICENSE.

## Entry point and scope

Launch `niri-preview.qml` through `haku-quickshell.service`.
The upstream `shell.qml` is retained as a reference for Hyprland; do not launch
that entry point in a Niri session.

The port reuses upstream island components, widgets and morph animations.
The compatibility service keeps the name `HyprlandService` to preserve those
interfaces, but subscribes to Niri events and dispatches Niri actions.
It does not apply Hyprland compositor settings.

## Public interfaces

- Three centered hover islands: statistics, clock and application tray.
- Fullscreen detection through Wayland ToplevelManager.
- Launcher, controls, notifications and media panel.
- On-demand clipboard, wallpaper carousel and shortcut reference.
- Independent session lock using WlSessionLock and PAM.
- Read-only and action-specific IPC targets documented with their components.

Desktop colors use the fixed Siamese palette of calli_dotfiles. Login/lock accents have a separate
wallpaper-derived source. Noctalia, Cava and the legacy Waybar are not required
by the active interface.

## Distribution boundaries

The guided installer (`./install.sh`) deploys the portable Niri profile and
uses a fade wallpaper path. On Arch, it offers upstream Niri or a packaged
SHORiN build pinned by `installer/niri-shorin/PKGBUILD`. Selecting the fork does
not enable hardware-specific settings or the personal profile.
Native recent-window previews, grid overview, magnifier and custom compositor
effects depend on the selected Niri version/fork and are not promised by the
portable profile. The package-manager widget is Arch-specific and disabled
when its backend is unavailable.

Do not run a second notification server alongside Haku. System authentication,
network and audio services must be configured by the distribution.

See [installation](../../../docs/INSTALL.md) and
[hover controls](../../../docs/edge-bar.md).
