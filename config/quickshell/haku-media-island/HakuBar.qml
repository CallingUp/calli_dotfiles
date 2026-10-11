import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray

// Native Quickshell replacement for the small Haku Waybar surface.  The
// expanded media card deliberately lives in shell.qml: that keeps this panel
// small and lets the overlay take (and release) outside-click input safely.
PanelWindow {
    id: root

    property bool barVisible: true
    property string accentHex: "#d9d8d9"
    property var workspaces: []
    property var players: []
    property int activeWorkspace: 1
    property var activePlayer: null
    signal mediaRequested()

    anchors { top: true; left: true; right: true }
    implicitHeight: barVisible ? 54 : 0
    color: "transparent"
    visible: barVisible
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Auto
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function choosePlayer() {
        let candidate = null;
        for (let i = 0; i < players.length; ++i) {
            const player = players[i];
            if (player && player.isPlaying) { candidate = player; break; }
            if (!candidate && player) candidate = player;
        }
        activePlayer = candidate;
    }

    function focusWorkspace(index) {
        focusWorkspaceProcess.command = ["niri", "msg", "action", "focus-workspace", String(index)];
        focusWorkspaceProcess.running = false;
        focusWorkspaceProcess.running = true;
    }

    FileView { id: themeFile; path: "/home/calli/.local/state/haku_theme/colors.css"; preload: true }

    function syncAccent() {
        const match = /@define-color\\s+accent_color\\s+(#[0-9A-Fa-f]{6})/.exec(themeFile.text());
        if (match) accentHex = match[1];
    }

    Process { id: focusWorkspaceProcess }
    Process {
        id: workspaceProcess
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector { id: workspaceOutput }
        onExited: (code) => {
            if (code !== 0) return;
            try {
                const data = JSON.parse(workspaceOutput.text.trim());
                root.workspaces = data.filter(ws => ws.idx > 0 && ws.idx <= 9);
                const focused = data.find(ws => ws.is_focused);
                if (focused) root.activeWorkspace = focused.idx;
            } catch (error) { }
        }
    }

    Instantiator {
        model: Mpris.players
        delegate: QtObject {
            property var player: modelData
            Component.onCompleted: {
                const list = root.players.slice();
                list.push(player);
                root.players = list;
                root.choosePlayer();
            }
            Component.onDestruction: {
                root.players = root.players.filter(p => p !== player);
                root.choosePlayer();
            }
        }
    }

    Timer {
        interval: 1000; running: root.visible; repeat: true
        onTriggered: { workspaceProcess.running = true; root.syncAccent(); root.choosePlayer(); }
    }
    Component.onCompleted: { workspaceProcess.running = true; syncAccent(); choosePlayer(); }

    Item {
        anchors.fill: parent

        Row {
            id: leftGroup
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 76; height: 40; radius: 15
                color: "#06070aff"; border.width: 1; border.color: Qt.darker(root.accentHex, 1.9)
                Row {
                    anchors.centerIn: parent; spacing: 7
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: index + 1 === root.activeWorkspace ? 15 : 8
                            height: 8; radius: 4
                            color: index + 1 === root.activeWorkspace ? root.accentHex : "#586174"
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            MouseArea { anchors.fill: parent; onClicked: root.focusWorkspace(index + 1) }
                        }
                    }
                }
            }

            Rectangle {
                width: clockText.implicitWidth + 28; height: 40; radius: 15
                color: "#06070aff"; border.width: 1; border.color: Qt.darker(root.accentHex, 1.9)
                Text {
                    id: clockText
                    anchors.centerIn: parent
                    property date now: new Date()
                    text: Qt.formatDateTime(now, "HH:mm:ss, dd MMMM yyyy")
                    color: "#e8edf4"; font.family: "CommitMono Nerd Font"; font.pixelSize: 13; font.bold: true
                }
                Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.now = new Date() }
            }
        }

        Rectangle {
            id: mediaCapsule
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(540, Math.max(320, mediaText.implicitWidth + 74)); height: 40; radius: 15
            color: "#06070aff"; border.width: 1; border.color: Qt.darker(root.accentHex, 1.9)
            Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: "♫"; color: root.accentHex; font.pixelSize: 16 }
            Text {
                id: mediaText
                anchors.centerIn: parent; width: parent.width - 68
                text: root.activePlayer ? ((root.activePlayer.trackArtist || "") + " :: " + (root.activePlayer.trackTitle || "Sin reproducción")) : "Sin reproducción"
                color: "#dbe7ff"; font.family: "CommitMono Nerd Font"; font.pixelSize: 13; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
            }
            MouseArea { anchors.fill: parent; onClicked: root.mediaRequested() }
        }

        Row {
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            Rectangle {
                width: trayRow.implicitWidth > 0 ? trayRow.implicitWidth + 16 : 0; height: 40; radius: 15
                visible: width > 0; color: "#06070aff"; border.width: 1; border.color: Qt.darker(root.accentHex, 1.9)
                Row {
                    id: trayRow; anchors.centerIn: parent; spacing: 7
                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            required property var modelData
                            width: 20; height: 20
                            Image { anchors.fill: parent; source: modelData.iconName ? "image://icon/" + modelData.iconName : ""; asynchronous: true }
                            MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: (mouse) => { if (mouse.button === Qt.LeftButton && !modelData.onlyMenu) modelData.activate(); else modelData.secondaryActivate(); } }
                        }
                    }
                }
            }
            Rectangle {
                width: 48; height: 40; radius: 15; color: "#06070aff"; border.width: 1; border.color: Qt.darker(root.accentHex, 1.9)
                Text { anchors.centerIn: parent; text: ""; color: root.accentHex; font.family: "CommitMono Nerd Font"; font.pixelSize: 16 }
                MouseArea { anchors.fill: parent; onClicked: powerProcess.running = true }
            }
        }
    }

    Process { id: powerProcess; command: ["noctalia", "msg", "panel-toggle", "session"] }
}
