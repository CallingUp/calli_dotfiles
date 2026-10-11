import QtQuick
import Quickshell.Io

// Adapted from Minflair's island-pill pattern for Niri: it starts at the
// exact geometry of the system capsule and grows into a compact quick panel.
Rectangle {
    id: root

    property bool open: false
    property real progress: open ? 1 : 0
    property real collapsedWidth: 190
    property real collapsedHeight: 40
    property string accentHex: "#d9d8d9"
    property string summary: "Sistema"

    width: collapsedWidth + (344 - collapsedWidth) * progress
    height: collapsedHeight + (242 - collapsedHeight) * progress
    radius: 15 - 3 * progress
    color: "#ff06070a"
    border.width: 1
    border.color: Qt.darker(accentHex, 1.9)
    clip: true
    visible: open || progress > 0.001

    Behavior on progress {
        NumberAnimation {
            duration: root.open ? 400 : 250
            easing.type: root.open ? Easing.OutQuint : Easing.OutCubic
        }
    }

    // It consumes the empty interior so that only a click truly outside this
    // rectangle reaches shell.qml. Declared before content so controls keep
    // their own pointer input.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; enabled: root.progress > 0.05 }

    Item {
        anchors.fill: parent
        opacity: Math.max(0, 1 - root.progress * 5)
        visible: opacity > 0
        Text {
            anchors.centerIn: parent
            text: root.summary
            color: "#e8edf4"
            font.family: "CommitMono Nerd Font"
            font.pixelSize: 12
            font.bold: true
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 18
        opacity: Math.max(0, Math.min(1, (root.progress - 0.12) / 0.60))
        scale: 0.96 + opacity * 0.04
        visible: opacity > 0

        Text {
            id: title
            anchors.top: parent.top
            anchors.left: parent.left
            text: "SISTEMA"
            color: root.accentHex
            font.family: "CommitMono Nerd Font"
            font.pixelSize: 13
            font.bold: true
        }
        Text {
            anchors.top: title.bottom
            anchors.topMargin: 7
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.summary
            color: "#c5d0e2"
            font.family: "CommitMono Nerd Font"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: controlCenter.top
            anchors.bottomMargin: 12
            spacing: 9

            Repeater {
                model: [
                    { icon: "󰕾 −", command: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
                    { icon: "󰕾 +", command: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" },
                    { icon: "󰃠 −", command: "brightnessctl set 5%-" },
                    { icon: "󰃠 +", command: "brightnessctl set 5%+" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 70; height: 43; radius: 10
                    color: actionMouse.containsMouse ? "#ff172238" : "#ff10151f"
                    border.width: 1; border.color: Qt.darker(root.accentHex, 1.9)
                    Text { anchors.centerIn: parent; text: modelData.icon; color: "#e8edf4"; font.family: "CommitMono Nerd Font"; font.pixelSize: 12; font.bold: true }
                    MouseArea { id: actionMouse; anchors.fill: parent; hoverEnabled: true; onClicked: actionProcess.run(modelData.command) }
                }
            }
        }

        Rectangle {
            id: controlCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 34; radius: 9
            color: "#ff10151f"; border.width: 1; border.color: Qt.darker(root.accentHex, 1.9)
            Text { anchors.centerIn: parent; text: "CENTRO DE CONTROL"; color: root.accentHex; font.family: "CommitMono Nerd Font"; font.pixelSize: 11; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: { controlCenterProcess.running = true; root.open = false; } }
        }
    }

    Process {
        id: actionProcess
        function run(script) {
            command = ["sh", "-c", script]
            running = false
            running = true
        }
    }
    Process { id: controlCenterProcess; command: ["noctalia", "msg", "panel-toggle", "control-center"] }
}
