import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Core
import qs.Core.Services
import "../../Modules/Music/Components/TimelineState.js" as TimelineState
pragma Singleton

Item {
    id: root

    property var managedPlayers: []
    property var availablePlayers: []
    property var availablePlayerIds: []
    property var playerDisplayNames: ({
    })
    property var activePlayer: null
    property var durationState: ({key: "", seconds: 0})
    property string durationRequestKey: ""
    readonly property bool timelineNeeded: ["music", "notificationsCenter", "dashboard", "controlCenter"].includes(AppState.activeWidget)
    onTimelineNeededChanged: {
        if (timelineNeeded) root.rememberDuration();
        else durationLookupTimer.stop();
    }
    readonly property string timelineUrl: root.activePlayer && root.activePlayer.metadata
        ? String(root.activePlayer.metadata["xesam:url"] || "") : ""
    readonly property string timelineKey: {
        const p = root.activePlayer;
        if (!p) return "";
        const url = p.metadata ? String(p.metadata["xesam:url"] || "") : "";
        return TimelineState.identity(p.dbusName || "", url, p.uniqueId);
    }
    readonly property real timelineDuration: {
        const p = root.activePlayer;
        if (!p) return 0;
        if (p.lengthSupported && Number.isFinite(p.length) && p.length > 0) return p.length;
        return root.durationState.key === root.timelineKey ? root.durationState.seconds : 0;
    }
    function rememberDuration() {
        const p = root.activePlayer;
        root.durationState = TimelineState.retainDuration(root.durationState, root.timelineKey,
            p !== null && p.lengthSupported, p ? p.length : 0);
        if (root.timelineNeeded && root.timelineDuration <= 0 && root.timelineUrl && root.durationRequestKey !== root.timelineKey)
            durationLookupTimer.restart();
    }
    onTimelineKeyChanged: root.rememberDuration()
    Connections {
        target: root.activePlayer
        function onLengthChanged() { root.rememberDuration(); }
        function onLengthSupportedChanged() { root.rememberDuration(); }
        function onMetadataChanged() { root.rememberDuration(); }
    }
    Timer {
        id: durationLookupTimer
        interval: 500
        onTriggered: {
            if (!root.timelineNeeded || root.timelineDuration > 0 || durationLookupProc.running || root.durationRequestKey === root.timelineKey) return;
            const match = root.timelineUrl.match(/^https:\/\/(?:www\.|music\.)?youtube\.com\/watch\?[^#]*\bv=([A-Za-z0-9_-]{11})(?:&|$)/)
                || root.timelineUrl.match(/^https:\/\/youtu\.be\/([A-Za-z0-9_-]{11})(?:[?&#]|$)/);
            if (!match) return;
            root.durationRequestKey = root.timelineKey;
            durationLookupProc.command = ["timeout", "20s", "yt-dlp", "--ignore-config", "--skip-download",
                "--no-playlist", "--no-warnings", "--socket-timeout", "8", "--retries", "0",
                "--print", "%(duration)s", "--", "https://www.youtube.com/watch?v=" + match[1]];
            durationLookupProc.running = true;
        }
    }
    Process {
        id: durationLookupProc
        stdout: StdioCollector { id: durationLookupOutput }
        onExited: exitCode => {
            if (root.durationRequestKey !== root.timelineKey) {
                if (root.timelineNeeded) durationLookupTimer.restart();
                return;
            }
            if (exitCode !== 0) return;
            const seconds = Number(durationLookupOutput.text.trim());
            if (root.timelineDuration <= 0 && Number.isFinite(seconds) && seconds > 0)
                root.durationState = {key: root.timelineKey, seconds: seconds};
        }
    }
    property var seekPlayer: null
    property real seekTarget: 0
    property int seekTrack: -1
    property int seekAttempts: 0
    property var recoveryPlayer: null
    property string recoveryKey: ""
    property real recoveryTarget: 0
    property int recoveryAttempts: 0
    IpcHandler {
        target: "haku-media-timeline"
        function status(): string {
            const p = root.activePlayer;
            return JSON.stringify(p ? {durationSupported: p.lengthSupported,
                positionSupported: p.positionSupported, duration: p.length,
                position: p.position, canSeek: p.canSeek,
                retainedDuration: root.timelineDuration,
                timelineNeeded: root.timelineNeeded,
                durationLookupRunning: durationLookupProc.running,
                pendingSeek: root.seekPlayer !== null} : {available: false});
        }
    }

    function seekTo(seconds) {
        const player = root.activePlayer;
        if (!player || !player.canSeek || !player.positionSupported || !Number.isFinite(seconds)) return;
        root.rememberDuration();
        const target = Math.max(0, root.timelineDuration > 0 ? Math.min(root.timelineDuration, seconds) : seconds);
        if (root.seekPlayer === player) { root.seekTarget = target; return; }
        const browser = (player.dbusName || "").toLowerCase().includes("firefox");
        if (!browser || !player.isPlaying) { player.position = target; return; }
        // Firefox may report Position=0 and lose length after a seek while playing.
        // Wait for Paused before SetPosition, then resume the same track.
        root.seekPlayer = player;
        root.seekTrack = player.uniqueId;
        root.seekTarget = target;
        root.seekAttempts = 0;
        player.pause();
        seekPauseTimer.restart();
    }
    function finishBrowserSeek() {
        const player = root.seekPlayer;
        if (!player) return;
        if (player.uniqueId !== root.seekTrack) { root.seekPlayer = null; return; }
        if (player.isPlaying) {
            root.seekAttempts++;
            if (root.seekAttempts < 20) seekPauseTimer.restart();
            else root.seekPlayer = null;
            return;
        }
        if (player.canSeek && player.positionSupported) player.position = root.seekTarget;
        player.play();
        root.recoveryPlayer = player;
        root.recoveryKey = root.timelineKey;
        root.recoveryTarget = root.seekTarget;
        recoveryCheckTimer.restart();
        root.seekPlayer = null;
    }
    Timer {
        id: seekPauseTimer
        interval: 50
        onTriggered: root.finishBrowserSeek()
    }
    Timer {
        id: recoveryCheckTimer
        interval: 250
        onTriggered: {
            if (!root.recoveryPlayer || root.recoveryKey !== root.timelineKey || root.recoveryTarget < 1 || recoveryReadProc.running) return;
            recoveryReadProc.command = ["busctl", "--user", "--timeout=2", "--json=short", "call",
                root.recoveryPlayer.dbusName, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties",
                "Get", "ss", "org.mpris.MediaPlayer2.Player", "Position"];
            recoveryReadProc.running = true;
        }
    }
    Process {
        id: recoveryReadProc
        stdout: StdioCollector { id: recoveryReadOutput }
        onExited: exitCode => {
            if (exitCode !== 0 || !root.recoveryPlayer || root.recoveryKey !== root.timelineKey) return;
            try {
                const value = JSON.parse(recoveryReadOutput.text).data[0].data;
                if (value === 0 && root.recoveryPlayer.isPlaying) {
                    root.recoveryAttempts = 0;
                    root.recoveryPlayer.pause();
                    recoveryResumeTimer.restart();
                } else root.recoveryPlayer = null;
            } catch (_) {}
        }
    }
    Timer {
        id: recoveryResumeTimer
        interval: 50
        onTriggered: {
            const p = root.recoveryPlayer;
            if (!p || root.recoveryKey !== root.timelineKey) return;
            if (p.isPlaying) {
                if (++root.recoveryAttempts < 20) restart();
                return;
            }
            p.play();
            root.recoveryPlayer = null;
        }
    }
    readonly property bool isPlaying: root.activePlayer !== null && (root.activePlayer.playbackState === 1 || root.activePlayer.playbackState === Mpris.Playing || String(root.activePlayer.playbackState).toLowerCase().includes("playing"))
    readonly property string activePlayerName: {
        if (!root.activePlayer)
            return "";

        let id = (root.activePlayer.identity || "").toLowerCase();
        let bus = (root.activePlayer.dbusName || "").toLowerCase();
        if (id.includes("spotify") || bus.includes("spotify"))
            return "Spotify";

        if (id.includes("youtube") || bus.includes("youtube"))
            return "YouTube Music";

        if (id.includes("kew") || bus.includes("kew"))
            return "Kew";

        if (id.includes("vlc") || bus.includes("vlc"))
            return "VLC";

        if (id.includes("mpv") || bus.includes("mpv"))
            return "mpv";

        return root.activePlayer.identity || root.getDisplayName(SettingsService.musicPlayer);
    }

    function toggleShuffle() {
        if (!root.activePlayer)
            return ;

        if (root.activePlayer.shuffleSupported) {
            root.activePlayer.shuffle = !root.activePlayer.shuffle;
        } else {
            let bus = root.activePlayer.dbusName || "";
            let pName = bus.replace("org.mpris.MediaPlayer2.", "");
            if (pName)
                mprisControlProc.command = ["playerctl", "-p", pName, "shuffle", "toggle"];
            else
                mprisControlProc.command = ["playerctl", "shuffle", "toggle"];
            mprisControlProc.running = false;
            mprisControlProc.running = true;
        }
    }

    function cycleLoop() {
        if (!root.activePlayer)
            return ;

        if (root.activePlayer.loopSupported) {
            let curr = root.activePlayer.loopState;
            let nextState = 0;
            // Cycle: None (0) -> Playlist (2) -> Track (1) -> None (0)
            if (curr === 0)
                nextState = 2;
            else if (curr === 2)
                nextState = 1;
            else
                nextState = 0;
            root.activePlayer.loopState = nextState;
        } else {
            let bus = root.activePlayer.dbusName || "";
            let pName = bus.replace("org.mpris.MediaPlayer2.", "");
            let nextArg = "toggle";
            if (pName)
                mprisControlProc.command = ["playerctl", "-p", pName, "loop", nextArg];
            else
                mprisControlProc.command = ["playerctl", "loop", nextArg];
            mprisControlProc.running = false;
            mprisControlProc.running = true;
        }
    }

    function getDisplayName(id) {
        if (!id || id === "none")
            return "None";

        if (id === "custom")
            return "Custom Command";

        if (root.playerDisplayNames && root.playerDisplayNames[id])
            return root.playerDisplayNames[id];

        for (let i = 0; i < root.availablePlayers.length; i++) {
            if (root.availablePlayers[i].id === id)
                return root.availablePlayers[i].name;

        }
        return id.split('-').map((word) => {
            return word.charAt(0).toUpperCase() + word.slice(1);
        }).join(' ');
    }

    function getPlayerById(id) {
        for (let i = 0; i < root.availablePlayers.length; i++) {
            if (root.availablePlayers[i].id === id)
                return root.availablePlayers[i];

        }
        return null;
    }

    function matchesConfiguredPlayer(p) {
        if (!p)
            return false;

        let pref = (SettingsService.musicPlayer || "").toLowerCase().trim();
        // Niri desktop: accept browser and application MPRIS players automatically.
        if (!pref || pref === "none" || pref === "auto")
            return true;
        if (!pref || pref === "none")
            return false;

        let id = (p.identity || "").toLowerCase();
        let desktop = (p.desktopEntry || "").toLowerCase();
        let bus = (p.dbusName || "").toLowerCase();
        if (pref === "custom") {
            let cmd = (SettingsService.musicPlayerCommand || "").toLowerCase().trim();
            if (!cmd)
                return false;

            let bin = cmd.split(" ")[0].replace(/^.*\//, '');
            if (!bin || bin === "kitty" || bin === "sh" || bin === "bash") {
                let parts = cmd.split(" ");
                for (let k = 1; k < parts.length; k++) {
                    if (!parts[k].startsWith("-")) {
                        bin = parts[k].replace(/^.*\//, '');
                        break;
                    }
                }
            }
            return bin !== "" && (id.includes(bin) || desktop.includes(bin) || bus.includes(bin));
        }
        if (pref === "youtube-music" || pref === "youtube")
            return id.includes("youtube") || desktop.includes("youtube") || bus.includes("youtube");

        if (pref === "spotify")
            return id.includes("spotify") || desktop.includes("spotify") || bus.includes("spotify");

        if (pref === "kew")
            return id.includes("kew") || desktop.includes("kew") || bus.includes("kew");

        if (pref === "vlc")
            return id.includes("vlc") || desktop.includes("vlc") || bus.includes("vlc");

        if (pref === "mpv")
            return id.includes("mpv") || desktop.includes("mpv") || bus.includes("mpv");

        let playerObj = getPlayerById(pref);
        if (playerObj) {
            let targetDesktop = (playerObj.desktopEntry || "").toLowerCase();
            let targetName = (playerObj.name || "").toLowerCase();
            let targetId = (playerObj.id || "").toLowerCase();
            let targetBin = (playerObj.exec || "").toLowerCase().split(" ")[0].replace(/^.*\//, '');
            if (targetDesktop && desktop !== "" && (desktop === targetDesktop || desktop.includes(targetDesktop) || targetDesktop.includes(desktop)))
                return true;

            if (targetId && (id.includes(targetId) || (desktop !== "" && desktop.includes(targetId)) || bus.includes(targetId)))
                return true;

            if (targetName && (id.includes(targetName) || (id !== "" && targetName.includes(id))))
                return true;

            if (targetBin && (id.includes(targetBin) || (desktop !== "" && desktop.includes(targetBin)) || bus.includes(targetBin)))
                return true;

        }
        return (pref !== "" && id.includes(pref)) || (pref !== "" && desktop !== "" && desktop.includes(pref)) || (pref !== "" && bus.includes(pref));
    }

    function getPlayerScore(p) {
        if (!p)
            return -100;

        let score = 0;
        let bus = (p.dbusName || "").toLowerCase();
        // Strongly prefer dedicated app MPRIS services over generic browser wrappers
        if (bus.includes("chromium") || bus.includes("chrome") || bus.includes("brave"))
            score -= 10;

        if (p.shuffleSupported)
            score += 5;

        if (p.loopSupported)
            score += 5;

        return score;
    }

    function updatePlayer() {
        let players = managedPlayers;
        let matchingPlaying = null;
        let matchingPaused = null;
        for (let i = 0; i < players.length; i++) {
            let p = players[i];
            if (!p)
                continue;

            if (matchesConfiguredPlayer(p)) {
                let active = p.playbackState === 1 || p.playbackState === Mpris.Playing || String(p.playbackState).toLowerCase().includes("playing");
                if (active) {
                    if (!matchingPlaying || getPlayerScore(p) > getPlayerScore(matchingPlaying))
                        matchingPlaying = p;

                } else {
                    if (!matchingPaused || getPlayerScore(p) > getPlayerScore(matchingPaused))
                        matchingPaused = p;

                }
            }
        }
        let chosen = matchingPlaying || matchingPaused || null;
        if (root.activePlayer !== chosen)
            root.activePlayer = chosen;

    }

    function registerPlayer(p) {
        let list = managedPlayers;
        if (list.indexOf(p) === -1) {
            list.push(p);
            managedPlayers = list;
            updatePlayer();
        }
    }

    function unregisterPlayer(p) {
        let list = managedPlayers, idx = list.indexOf(p);
        if (idx !== -1) {
            list.splice(idx, 1);
            managedPlayers = list;
            updatePlayer();
        }
    }

    function formatTime(s) {
        if (isNaN(s) || s < 0)
            return "0:00";

        let m = Math.floor(s / 60), sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    function launchPlayer() {
        if (!SettingsService.musicPlayer || SettingsService.musicPlayer === "" || SettingsService.musicPlayer === "none")
            return ;

        let playerObj = getPlayerById(SettingsService.musicPlayer);
        let cmd = "";
        let isTerminal = false;
        if (SettingsService.musicPlayer === "custom") {
            cmd = SettingsService.musicPlayerCommand;
        } else if (playerObj) {
            cmd = playerObj.exec;
            isTerminal = playerObj.terminal;
        } else {
            cmd = SettingsService.musicPlayerCommand || SettingsService.musicPlayer;
        }
        if (!cmd || cmd.trim() === "")
            return ;

        let parts = cmd.trim().split(" ").filter((x) => {
            return x !== "";
        });
        if (isTerminal && parts[0] !== "kitty" && parts[0] !== "alacritty" && parts[0] !== "foot")
            parts = ["kitty", "-e"].concat(parts);

        launcherProc.command = parts;
        launcherProc.running = false;
        launcherProc.startDetached();
    }

    function killConfiguredPlayer() {
        if (!SettingsService.musicPlayer || SettingsService.musicPlayer === "" || SettingsService.musicPlayer === "none")
            return ;

        let cmd = SettingsService.musicPlayerCommand;
        if (!cmd || cmd.trim() === "")
            cmd = SettingsService.musicPlayer;

        if (!cmd || cmd.trim() === "")
            return ;

        let parts = cmd.trim().split(" ");
        let binary = parts[0];
        if (binary === "kitty" || binary === "sh" || binary === "bash") {
            for (let i = 1; i < parts.length; i++) {
                if (!parts[i].startsWith("-")) {
                    binary = parts[i];
                    break;
                }
            }
        }
        binary = binary.replace(/^.*\//, '');
        if (binary) {
            killProc.command = ["killall", "-9", binary];
            killProc.running = false;
            killProc.running = true;
        }
    }

    Process {
        id: playerScannerProc

        command: ["bash", Quickshell.env("HOME") + "/haku_shell/scripts/bin/haku-info-worker", "players"]
        Component.onCompleted: running = true
        onExited: (exitCode) => {
            if (exitCode === 0) {
                try {
                    let parsed = JSON.parse(playerScannerOutput.text.trim());
                    if (Array.isArray(parsed)) {
                        root.availablePlayers = parsed;
                        let ids = [];
                        let names = {
                        };
                        for (let i = 0; i < parsed.length; i++) {
                            let p = parsed[i];
                            ids.push(p.id);
                            names[p.id] = p.name;
                        }
                        root.availablePlayerIds = ids;
                        root.playerDisplayNames = names;
                        root.updatePlayer();
                    }
                } catch (e) {
                    console.error("Error parsing music players: " + e);
                }
            }
        }

        stdout: StdioCollector {
            id: playerScannerOutput
        }

    }

    Process {
        id: launcherProc
    }

    Process {
        id: killProc
    }

    Process {
        id: mprisControlProc
    }

    Connections {
        function onMusicPlayerChanged() {
            root.updatePlayer();
        }

        function onMusicPlayerCommandChanged() {
            root.updatePlayer();
        }

        target: SettingsService
    }

    Timer {
        running: root.isPlaying && root.timelineNeeded
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.activePlayer)
                root.activePlayer.positionChanged();

        }
    }

    Instantiator {
        model: Mpris.players

        delegate: QtObject {
            property var p: modelData
            property var state: p.playbackState
            property var title: p.trackTitle

            onStateChanged: root.updatePlayer()
            onTitleChanged: root.updatePlayer()
            Component.onCompleted: root.registerPlayer(p)
            Component.onDestruction: root.unregisterPlayer(p)
        }

    }

}
