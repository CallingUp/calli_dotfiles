import QtQuick

Item {
    id: handle
    property color accent: "#b99573"
    property real revealProgress: 0
    readonly property bool hovered: hover.hovered
    implicitWidth: 96
    implicitHeight: 6
    Rectangle {
        width: parent.width
        height: 1
        radius: 0.5
        color: handle.accent
        opacity: 0.15 * (1 - handle.revealProgress)
    }
    HoverHandler { id: hover; blocking: false }
}
