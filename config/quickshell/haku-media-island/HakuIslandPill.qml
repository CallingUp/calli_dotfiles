import QtQuick

// Generic host pill adapted from Minflair's three Island*Pill components.
// Niri has no Hyprland focus-grab here; the ShellRoot routes host actions and
// keeps keyboard focus policy unchanged.
Rectangle {
    id: root

    property string side: "center"
    property bool target: false
    property real progress: 0
    property real collapsedWidth: 180
    property string accentHex: "#d9d8d9"
    property string compactText: ""
    property var activePlayer: null
    property var cavaLevels: []
    property int activeWorkspace: 1
    property int workspaceCount: 4
    property Component contentComponent: null
    readonly property real contentWidth: contentLoader.item && contentLoader.item.implicitWidth > 0 ? contentLoader.item.implicitWidth : 0
    readonly property real contentHeight: contentLoader.item && contentLoader.item.implicitHeight > 0 ? contentLoader.item.implicitHeight : 0
    readonly property real expandedWidth: contentWidth > 0 ? contentWidth + 36 : collapsedWidth
    readonly property real expandedHeight: contentHeight > 0 ? contentHeight + 36 : 40
    signal closeRequested()
    signal workspaceRequested(int index)

    width: collapsedWidth + (expandedWidth - collapsedWidth) * progress
    height: 40 + (expandedHeight - 40) * progress
    radius: 15 - 3 * progress
    color: "#ff080a0f"
    border.width: progress > 0.12 ? 1 : 0
    border.color: Qt.darker(accentHex, 1.9)
    clip: true
    visible: target && progress > 0.001
    z: target ? 10 : 1

    HoverHandler {
        id: hover
        enabled: root.progress < 0.001
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.progress > 0.05
    }

    Item {
        anchors.fill: parent
        opacity: Math.max(0, 1 - root.progress / 0.15)
        visible: opacity > 0.001
        clip: true

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: compactCava.left
            anchors.rightMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            visible: root.side === "center"
            text: root.compactText
            color: root.accentHex
            font.family: "CommitMono Nerd Font"
            font.pixelSize: 13
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.centerIn: parent
            visible: root.side === "right"
            text: root.compactText
            color: root.accentHex
            font.family: "CommitMono Nerd Font"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }

        Row {
            anchors.centerIn: parent
            spacing: 10
            visible: root.side === "left"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                Repeater {
                    model: root.workspaceCount
                    delegate: Rectangle {
                        required property int index
                        width: index + 1 === root.activeWorkspace ? 15 : 8
                        height: 8
                        radius: 4
                        color: root.accentHex
                        opacity: index + 1 === root.activeWorkspace ? 1 : 0.32
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.compactText
                color: root.accentHex
                font.family: "CommitMono Nerd Font"
                font.pixelSize: 13
                font.bold: true
            }
        }

        HakuCava {
            id: compactCava
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            active: root.side === "center" && root.progress < 0.22
            levels: root.cavaLevels
            barColor: root.accentHex
        }
    }

    Item {
        id: contentSurface
        anchors.fill: parent
        anchors.margins: 18
        opacity: root.progress < 0.2 ? 0 : Math.min(1, (root.progress - 0.20) / 0.60)
        scale: 0.94 + 0.06 * opacity
        visible: opacity > 0.001
        clip: true

        Loader {
            id: contentLoader
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: item && item.implicitWidth > 0 ? item.implicitWidth : parent.width
            height: item && item.implicitHeight > 0 ? item.implicitHeight : parent.height
            active: root.target && root.progress > 0.15
            sourceComponent: root.contentComponent
            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        Connections {
            target: contentLoader.item
            function onCloseRequested() { root.closeRequested(); }
            function onWorkspaceRequested(index) { root.workspaceRequested(index); }
        }
    }

    transform: Translate {
        x: root.side === "left" && (hover.hovered || root.target) ? -4
         : root.side === "right" && (hover.hovered || root.target) ? 4 : 0
        y: hover.hovered || root.target ? 4 : 0
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
    }
}
