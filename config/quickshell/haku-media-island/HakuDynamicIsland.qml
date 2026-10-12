import QtQuick
import Quickshell.Io

// Niri port of Minflair's IslandBar state machine: three stationary host
// pills share one active target, one close/open handover, and lazy content.
Item {
    id: root

    property string target: ""
    property string queuedTarget: ""
    property bool open: false
    property real progress: 0
    property string accentHex: "#d9d8d9"
    property string summary: ""
    property var activePlayer: null
    property var cavaLevels: []
    property int activeWorkspace: 1
    property int workspaceCount: 4
    property date now: new Date()

    property real mediaX: 0
    property real mediaWidth: 320
    property real systemRightX: 0
    property real systemWidth: 200
    property real leftX: 8
    property real leftWidth: 250

    readonly property bool active: target !== "" && progress > 0.001
    onOpenChanged: progress = open ? 1 : 0

    function focusWorkspace(index) {
        focusWorkspaceProcess.command = ["niri", "msg", "action", "focus-workspace", String(index)];
        focusWorkspaceProcess.running = false;
        focusWorkspaceProcess.running = true;
    }

    function openTarget(nextTarget) {
        if (target === nextTarget && open)
            return;
        if (progress > 0.001) {
            queuedTarget = nextTarget;
            open = false;
            return;
        }
        target = nextTarget;
        open = true;
    }

    function toggleTarget(nextTarget) {
        if (target === nextTarget && open)
            close();
        else
            openTarget(nextTarget);
    }

    function close() {
        queuedTarget = "";
        open = false;
    }

    function settle() {
        if (open || progress > 0.001)
            return;
        if (queuedTarget !== "") {
            target = queuedTarget;
            queuedTarget = "";
            open = true;
        } else {
            target = "";
        }
    }

    anchors.fill: parent
    visible: active

    Behavior on progress {
        NumberAnimation {
            duration: root.open ? 430 : 280
            easing.type: root.open ? Easing.OutQuint : Easing.OutCubic
            onRunningChanged: if (!running) root.settle()
        }
    }

    Component {
        id: mediaContent
        MediaIsland { activePlayer: root.activePlayer; accentHex: root.accentHex }
    }
    Component {
        id: systemContent
        SystemIsland { summary: root.summary; accentHex: root.accentHex }
    }
    Component {
        id: workspaceContent
        WorkspaceIsland {
            accentHex: root.accentHex
            activeWorkspace: root.activeWorkspace
            workspaceCount: root.workspaceCount
        }
    }

    HakuIslandPill {
        id: leftPill
        x: root.leftX
        y: 7
        side: "left"
        target: root.target === "left"
        progress: target ? root.progress : 0
        collapsedWidth: root.leftWidth
        accentHex: root.accentHex
        contentComponent: workspaceContent
        compactText: Qt.formatDateTime(root.now, "HH:mm:ss, dd MMM yyyy")
        activeWorkspace: root.activeWorkspace
        workspaceCount: root.workspaceCount
        onWorkspaceRequested: (index) => { root.focusWorkspace(index); root.close(); }
    }

    HakuIslandPill {
        id: centerPill
        x: root.mediaX - (width - collapsedWidth) / 2
        y: 7
        side: "center"
        target: root.target === "media"
        progress: target ? root.progress : 0
        collapsedWidth: root.mediaWidth
        accentHex: root.accentHex
        contentComponent: mediaContent
        compactText: root.activePlayer ? ((root.activePlayer.trackArtist || "") + " :: " + (root.activePlayer.trackTitle || "Sin reproducción")) : "Sin reproducción"
        activePlayer: root.activePlayer
        cavaLevels: root.cavaLevels
    }

    HakuIslandPill {
        id: rightPill
        x: root.systemRightX - width
        y: 7
        side: "right"
        target: root.target === "system"
        progress: target ? root.progress : 0
        collapsedWidth: root.systemWidth
        accentHex: root.accentHex
        contentComponent: systemContent
        compactText: root.summary
        onCloseRequested: root.close()
    }

    Connections {
        target: leftPill
        function onCloseRequested() { root.close(); }
    }
    Process { id: focusWorkspaceProcess }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
