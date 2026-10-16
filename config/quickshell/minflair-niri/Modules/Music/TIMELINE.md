# Timeline / Firefox recovery

Only use MPRIS `length` as duration when `lengthSupported` is true. Otherwise
Quickshell returns position as length, which produced a permanently full bar.
Keep the last supported duration for the same player/video, not across tracks.
YouTube identity uses the video ID, ignoring URL timestamp changes.

If no supported duration is available, resolve public YouTube duration once per
track with the installed yt-dlp, ignore-config, no cookies, no download, no
playlist, and a 20-second bound. Do not invent durations for live streams or
failed requests. Native MPRIS duration takes precedence when it becomes available.
This fallback is transient and only runs on missing duration, not each second.
It is also lazy: no lookup is scheduled while timeline panels are closed.
Opening a timeline panel retries scheduling for its current track. Closing it
cancels the debounce, not an already running bounded lookup; its useful result
is kept for that track. Track changes while closed do not start another lookup.
The native MPRIS metadata and track-duration cache still update while closed.

Commit seeks on mouse release, not every drag event. Firefox seeks wait for Pause
before SetPosition and resume afterward. A single direct D-Bus Position check
after the seek detects the known zero-position regression; only if detected,
perform another short Pause/Play recovery on the same track. No perpetual poll
or browser extension is introduced.

```sh
node ~/haku_shell/config/quickshell/minflair-niri/Modules/Music/test_seek.cjs
quickshell ipc -p ~/haku_shell/config/quickshell/minflair-niri/niri-preview.qml call haku-media-timeline status
```

Tests use fake players and the actual service functions. They do not seek the
user's video. Real drag behavior still needs user verification in Zen.
