import QtQuick

// Content component loaded by HakuDynamicIsland, following Minflair's
// pill -> delayed content-loader pattern while keeping Haku's MPRIS actions.
Item {
    id: root

    property var activePlayer: null
    property string accentHex: "#d9d8d9"
    property color accent: accentHex
    signal closeRequested()
    signal workspaceRequested(int index)

    implicitWidth: 524
    implicitHeight: 250

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
        color: "#ff151a24"
        visible: !art.visible
        Text { anchors.centerIn: parent; text: "♫"; color: root.accent; font.pixelSize: 54 }
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
            color: "#fff3f6ff"
            font.family: "CommitMono Nerd Font"
            font.pixelSize: 18
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.activePlayer ? (root.activePlayer.trackArtist || "Artista desconocido") : ""
            color: root.accent
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
            model: ["⏮", "▶", "⏭"]
            delegate: Rectangle {
                required property int index
                required property string modelData
                width: 54; height: 38; radius: 10
                color: mouse.containsMouse ? "#ff172238" : "#ff10151f"
                border.width: 1; border.color: Qt.darker(root.accent, 1.9)
                Text { anchors.centerIn: parent; text: modelData; color: root.accent; font.pixelSize: 18 }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (!root.activePlayer) return;
                        if (index === 0) root.activePlayer.previous();
                        else if (index === 1) root.activePlayer.togglePlaying();
                        else root.activePlayer.next();
                    }
                }
            }
        }
    }
}
