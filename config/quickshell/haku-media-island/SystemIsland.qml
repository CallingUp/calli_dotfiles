import QtQuick
import Quickshell.Io

// Expanded system capsule content; the common island shell handles sizing,
// movement and the opening/closing progress shared with the other targets.
Item {
    id: root

    property string accentHex: "#d9d8d9"
    property color accent: accentHex
    property string summary: "Sistema"
    signal closeRequested()
    signal workspaceRequested(int index)

    implicitWidth: 308
    implicitHeight: 206

    Text {
        id: title
        anchors.top: parent.top
        anchors.left: parent.left
        text: "SISTEMA"
        color: root.accent
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
        color: "#ffe8edf4"
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
                border.width: 1; border.color: Qt.darker(root.accent, 1.9)
                Text { anchors.centerIn: parent; text: modelData.icon; color: root.accent; font.family: "CommitMono Nerd Font"; font.pixelSize: 12; font.bold: true }
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
        color: "#ff10151f"; border.width: 1; border.color: Qt.darker(root.accent, 1.9)
        Text { anchors.centerIn: parent; text: "CENTRO DE CONTROL"; color: root.accent; font.family: "CommitMono Nerd Font"; font.pixelSize: 11; font.bold: true }
        MouseArea { anchors.fill: parent; onClicked: { controlCenterProcess.running = true; root.closeRequested(); } }
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
