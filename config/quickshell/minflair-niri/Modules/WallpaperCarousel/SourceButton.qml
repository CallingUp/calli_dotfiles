import QtQuick

Rectangle {
    id: button
    property string label: ""
    property bool active: false
    signal clicked()
    implicitWidth: caption.implicitWidth + 24
    implicitHeight: 34
    radius: 8
    color: active ? Qt.alpha(root.accent, 0.22) : area.containsMouse ? "#25262c" : "#18191e"
    Text {
        id: caption
        anchors.centerIn: parent
        text: button.label
        color: button.active ? root.accent : "#dedee6"
        font { family: root.settings.font; pixelSize: 12; bold: button.active }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: button.clicked() }
}
