import QtQuick
import qs.Core
import qs.Core.Services

IslandBackground {
    id: root
    readonly property bool hovered: hover.hovered
    width: metrics.implicitWidth + 24
    height: 32
    radius: Constants.sizeLg
    Text {
        id: metrics
        anchors.centerIn: parent
        font.family: Constants.fontFamily
        font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
        font.bold: true
        color: Theme.fg
        text: " " + Math.round(SystemStats.cpuUsage) + "%    "
            + SystemStats.memUsed.toFixed(1) + "G    " + SystemStats.cpuTemperature
    }
    HoverHandler { id: hover; blocking: false }
}
