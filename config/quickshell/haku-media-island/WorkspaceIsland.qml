import QtQuick

Item {
    id: root

    property string accentHex: "#d9d8d9"
    property int activeWorkspace: 1
    property int workspaceCount: 4
    property date now: new Date()
    signal workspaceRequested(int index)
    signal closeRequested()

    implicitWidth: 384
    implicitHeight: 182

    Column {
        anchors.centerIn: parent
        spacing: 9
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.accentHex
            font.family: "CommitMono Nerd Font"
            font.pixelSize: 52
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, dd MMMM yyyy")
            color: "#ffe8edf4"
            font.family: "CommitMono Nerd Font"
            font.pixelSize: 12
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Repeater {
                model: root.workspaceCount
                delegate: Rectangle {
                    required property int index
                    width: index + 1 === root.activeWorkspace ? 18 : 9
                    height: 9; radius: 5
                    color: root.accentHex
                    opacity: index + 1 === root.activeWorkspace ? 1 : 0.38
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    MouseArea { anchors.fill: parent; onClicked: root.workspaceRequested(index + 1) }
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
