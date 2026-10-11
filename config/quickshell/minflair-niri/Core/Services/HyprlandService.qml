pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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
    property bool isTrueFullscreen: false
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
    function refreshWorkspaces() { if (!workspaceQuery.running) workspaceQuery.running = true; }
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
        id: windowQuery
        command: ["niri", "msg", "-j", "focused-window"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { const window = JSON.parse(text); backend.isTrueFullscreen = !!window && window.is_fullscreen === true; }
                catch (e) {}
            }
        }
    }
    Timer { interval: 700; running: true; repeat: true; onTriggered: { backend.refreshWorkspaces(); if (!windowQuery.running) windowQuery.running = true; } }
}
