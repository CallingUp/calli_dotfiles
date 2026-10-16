pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core

// Compatibility API for upstream Minflair; never writes compositor preferences.
Item {
    id: backend
    property bool enableAnimations: true
    property real animationSpeedFactor: 1
    property string keyboardLayout: "us"
    property bool wpAutoShuffle: false
    property int wpShuffleInterval: 10
    property bool wpEnableTransitions: true
    property string wpTransitionType: "grow"
    property string wpTransitionPos: "center"
    property int wpTransitionStep: 120
    property int wpTransitionFps: 60
    property int wpTransitionAngle: 30
    property string wpResizeMode: "crop"
    property string wpCropGravity: "center"
    property bool hyprBlur: true
    property int hyprRounding: Constants.size3Xl
    property int hyprActiveOpacity: 100
    property int hyprInactiveOpacity: 100
    property int hyprBlurSize: 6
    property int hyprBlurPasses: 4
    property int hyprGapsIn: 4
    property int hyprGapsOut: 8
    property int hyprBorderSize: 0
    property bool hyprShadow: true
    property int hyprShadowRange: 8
    property int hyprShadowRenderPower: 3
    property real mouseSensitivity: 0
    property string mouseAccelProfile: "flat"
    property bool mouseNaturalScroll: false
    property real mouseScrollFactor: 1
    property bool mouseLeftHanded: false
    property int mouseFollowMouse: 1
    property int cursorInactiveTimeout: 5
    property bool cursorNoWarps: false
    property bool touchpadNaturalScroll: true
    property bool touchpadTapToClick: true
    property bool touchpadDisableWhileTyping: true
    property bool hyprPrefsLoaded: true
    property bool isSyncing: false
    readonly property bool isTrueFullscreen: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false
    property var activeCasts: []
    readonly property bool isScreencasting: activeCasts.length > 0
    property var workspaces: ({ values: [] })
    property var toplevels: ({ values: [] })
    property var focusedWorkspace: null
    signal rawEvent(var event)
    function reloadHyprPrefs() {}
    function startupAnimations() {}
    function triggerStartupTimer() {}
    function applyHyprlandSettings() {}
    function applyMouseSettings() {}
    function setPowerSaverMode(enabled) {}
    property bool workspaceRefreshPending: false
    function refreshWorkspaces() {
        workspaceRefreshPending = true;
        workspaceRefreshDebounce.restart();
    }
    Timer {
        id: workspaceRefreshDebounce
        interval: 40
        onTriggered: {
            if (!workspaceQuery.running && backend.workspaceRefreshPending) {
                backend.workspaceRefreshPending = false;
                workspaceQuery.running = true;
            }
        }
    }
    function dispatch(command) {
        const match = command.match(/workspace=(\d+)/);
        if (match) focusWorkspace(Number(match[1]));
    }
    function focusWorkspace(index) {
        action.command = ["niri", "msg", "action", "focus-workspace", String(index)];
        action.running = true;
    }
    Process { id: action }
    Process {
        id: workspaceQuery
        command: ["niri", "msg", "-j", "workspaces"]
        running: true
        onExited: {
            // Events received during a query must not be lost.
            if (backend.workspaceRefreshPending) workspaceRefreshDebounce.restart();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    backend.workspaces = { values: list.map(w => ({ id: w.idx, name: w.name, toplevels: { values: w.active_window_id === null ? [] : [{}] } })) };
                    const active = list.find(w => w.is_focused);
                    backend.focusedWorkspace = active ? {id: active.idx} : null;
                } catch (e) { console.warn("Niri workspace query:", e); }
            }
        }
    }
    Process {
        id: niriEvents
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        onStarted: backend.refreshWorkspaces()
        onExited: eventReconnect.restart()
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("Workspace") || data.includes("Window")) backend.refreshWorkspaces();
                if (data.includes("Cast")) {
                    try {
                        const event = JSON.parse(data);
                        if (event.CastsChanged) backend.activeCasts = event.CastsChanged.casts;
                        if (event.CastStartedOrChanged) {
                            const cast = event.CastStartedOrChanged.cast;
                            backend.activeCasts = backend.activeCasts.filter(c => c.stream_id !== cast.stream_id).concat([cast]);
                        }
                        if (event.CastStopped) backend.activeCasts = backend.activeCasts.filter(c => c.stream_id !== event.CastStopped.stream_id);
                    } catch (error) { console.warn("Niri cast event:", error); }
                }
            }
        }
    }
    // No workspace polling while connected. Reconnect and resync on failure.
    Timer {
        id: eventReconnect
        interval: 2000
        onTriggered: if (!niriEvents.running) niriEvents.running = true
    }
    Timer {
        interval: 3000
        running: !niriEvents.running
        repeat: true
        onTriggered: backend.refreshWorkspaces()
    }
}
