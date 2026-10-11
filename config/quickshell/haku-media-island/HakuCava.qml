import QtQuick
// Renderer for the shared CavaSource. Its 28 split-stereo bands are sampled
// into ten bars without widening the media capsule.
Item {
    id: root

    property color barColor: "#d9d8d9"
    property bool active: false
    property var levels: []
    property int barCount: 10

    implicitWidth: barCount * 3 + (barCount - 1) * 2
    implicitHeight: 18
    width: implicitWidth
    height: implicitHeight
    visible: active

    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: root.barCount
            delegate: Item {
                required property int index
                width: 3
                height: root.height
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: Math.max(3, Math.min(root.height, 3 + (root.levels[index] || 0) * (root.height - 3)))
                    radius: 1.5
                    color: root.barColor
                    opacity: 0.92
                    Behavior on height { NumberAnimation { duration: 85; easing.type: Easing.OutQuad } }
                }
            }
        }
    }
}
