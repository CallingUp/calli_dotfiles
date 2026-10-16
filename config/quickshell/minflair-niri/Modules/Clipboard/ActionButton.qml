import QtQuick

Rectangle {
    id: button
    property string label: ""
    property bool active: false
    signal clicked()
    implicitWidth: caption.implicitWidth + 22
    implicitHeight: 34
    radius: 8
    color: active ? Qt.alpha(root.settings.accent, 0.24) : area.containsMouse ? "#24252b" : "#191a1f"
    opacity: enabled ? 1 : 0.4
    Text {
        id: caption
        anchors.centerIn: parent
        text: button.label
        color: button.active ? root.settings.accent : "#dedee6"
        font { family: root.settings.font; pixelSize: 12; bold: button.active }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: button.clicked() }
}
