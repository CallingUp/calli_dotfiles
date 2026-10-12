import QtQuick
import QtQuick.Templates as T
import qs.Core

T.Button {
    id: actionButton
    property bool primary: false
    hoverEnabled: true
    implicitHeight: 34
    implicitWidth: Math.max(90, contentItem.implicitWidth + 28)
    padding: 10
    opacity: enabled ? 1 : 0.45
    contentItem: Text {
        text: actionButton.text
        font.family: Constants.fontFamily
        font.pixelSize: 12
        font.bold: true
        color: actionButton.primary ? Theme.accent : Theme.fg
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: Constants.sizeSm
        color: actionButton.down ? Theme.bgTertiary
            : actionButton.hovered || actionButton.primary ? Theme.bgAccent : Theme.bgSecondary
        border.width: actionButton.visualFocus ? 1 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 100 } }
    }
}
