import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

Rectangle {
    id: root

    property bool open: false
    property real progress: open ? 1 : 0
    property var activePlayer: null
    property var cavaLevels: []
    property var controls: ["⏮", "▶", "⏭"]

    property string accentHex: "#d9d8d9"
    readonly property color accent: accentHex
    readonly property color background: "#080a0f"
    readonly property color borderColor: Qt.darker(accent, 1.9)
    // Supplied by HakuBar so this is literally the same capsule, not a
    // similarly-looking popup placed over it.
    property real collapsedWidth: 450
    property real collapsedHeight: 40
    readonly property real expandedWidth: 560
    readonly property real expandedHeight: 286

    function choosePlayer() {
        let candidate = null;
        for (let i = 0; i < players.length; ++i) {
            const player = players[i];
            if (player && player.isPlaying) {
                candidate = player;
                break;
            }
            if (!candidate && player)
                candidate = player;
        }
        activePlayer = candidate;
    }

    width: collapsedWidth + (expandedWidth - collapsedWidth) * progress
    height: collapsedHeight + (expandedHeight - collapsedHeight) * progress
    radius: 15 - 3 * progress
    // The native Quickshell bar owns idle state. This surface becomes the
    // central pill for the whole open/close animation.
    visible: open || progress > 0.001
    color: background
    border.width: 1
    border.color: borderColor
    clip: true

    Behavior on progress {
        NumberAnimation {
            duration: root.open ? 430 : 280
            easing.type: root.open ? Easing.OutQuint : Easing.OutCubic
        }
    }

    property var players: []

    FileView {
        id: themeFile
        path: "/home/calli/.local/state/haku_theme/colors.css"
        preload: true
    }

    function syncAccent() {
        const match = /@define-color\\s+accent_color\\s+(#[0-9A-Fa-f]{6})/.exec(themeFile.text());
        if (match)
            accentHex = match[1];
    }

    Component.onCompleted: syncAccent()

    Timer {
        interval: 1800
        running: true
        repeat: true
        onTriggered: root.syncAccent()
    }

    Instantiator {
        model: Mpris.players
        delegate: QtObject {
            property var player: modelData
            property var title: player.trackTitle
            property bool playing: player.isPlaying
            Component.onCompleted: {
                const list = root.players.slice();
                list.push(player);
                root.players = list;
                root.choosePlayer();
            }
            Component.onDestruction: {
                const list = root.players.filter(p => p !== player);
                root.players = list;
                root.choosePlayer();
            }
            onTitleChanged: root.choosePlayer()
            onPlayingChanged: root.choosePlayer()
        }
    }

    Item {
        id: compactContent
        anchors.fill: parent
        opacity: Math.max(0, 1 - progress * 5)
        visible: opacity > 0

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: compactCava.left
            anchors.rightMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            text: root.activePlayer ? ((root.activePlayer.trackArtist || "") + " :: " + (root.activePlayer.trackTitle || "Sin reproducción")) : "Sin reproducción"
            color: root.accent
            font.family: "CommitMono Nerd Font"
            font.pixelSize: 13
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
        HakuCava {
            id: compactCava
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            // This short-lived instance is only active during the geometric
            // handoff; the bar process is stopped at the same moment.
            active: root.visible && root.progress < 0.22
            levels: root.cavaLevels
            barColor: root.accent
        }
    }

    Item {
        id: expandedContent
        anchors.fill: parent
        anchors.margins: 18
        opacity: Math.max(0, Math.min(1, (progress - 0.16) / 0.58))
        scale: 0.96 + 0.04 * opacity
        visible: opacity > 0

        Image {
            id: art
            anchors.left: parent.left
            anchors.top: parent.top
            width: 164
            height: width
            source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: status === Image.Ready
        }

        Rectangle {
            anchors.fill: art
            color: "#151a24"
            visible: !art.visible
            Text {
                anchors.centerIn: parent
                text: "♫"
                color: root.accent
                font.pixelSize: 54
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.top: art.top
            spacing: 7

            Text {
                width: parent.width
                text: root.activePlayer ? (root.activePlayer.trackTitle || "Sin título") : "Sin reproducción"
                color: "#f3f6ff"
                font.family: "CommitMono Nerd Font"
                font.pixelSize: 18
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.activePlayer ? (root.activePlayer.trackArtist || "Artista desconocido") : ""
                color: "#9eafca"
                font.family: "CommitMono Nerd Font"
                font.pixelSize: 13
                elide: Text.ElideRight
            }
            Text {
                text: root.activePlayer && root.activePlayer.isPlaying ? "EN REPRODUCCIÓN" : "EN PAUSA"
                color: root.accent
                font.family: "CommitMono Nerd Font"
                font.pixelSize: 11
                font.bold: true
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 20

            Repeater {
                model: root.controls
                delegate: Rectangle {
                    required property int index
                    width: 54
                    height: 38
                    radius: 10
                    color: controlMouse.containsMouse ? "#172238" : "#10151f"
                    border.width: 1
                    border.color: root.borderColor
                    Text {
                        anchors.centerIn: parent
                        text: root.controls[index]
                        color: "#e2ebff"
                        font.pixelSize: 18
                    }
                    MouseArea {
                        id: controlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!root.activePlayer)
                                return;
                            if (index === 0) root.activePlayer.previous();
                            else if (index === 1) root.activePlayer.togglePlaying();
                            else root.activePlayer.next();
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        enabled: root.progress < 0.05
        onClicked: root.open = !root.open
    }
}
