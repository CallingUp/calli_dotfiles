import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root
    implicitWidth: content.implicitWidth + 24
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 10
        ThemedText { text: " " + Math.round(SystemStats.cpuUsage) + "%"; color: Theme.accent }
        ThemedText { text: " " + Math.round(SystemStats.memPercent) + "%" }
        ThemedText { text: " " + SystemStats.cpuTemperature }
    }
}
