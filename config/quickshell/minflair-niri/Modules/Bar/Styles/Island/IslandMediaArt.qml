import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Components

Item {
    id: root
    property bool clickable: true
    readonly property bool showMedia: MprisService.activePlayer !== null && ((MprisService.activePlayer.trackTitle || "").trim() !== "")
    readonly property string caption: showMedia ? ((MprisService.activePlayer.trackArtist || "").trim() ? MprisService.activePlayer.trackArtist + " :: " : "") + MprisService.activePlayer.trackTitle : "Media"
    implicitWidth: Math.min(300, label.implicitWidth) + visualizer.width + 26
    clip: true
    ThemedText {
        id: label
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: visualizer.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.caption
        elide: Text.ElideRight
        color: Theme.accent
    }
    MiniCavaBars {
        id: visualizer
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        barCount: 12
        maxBarHeight: 16
        barColor: Theme.accent
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: root.clickable
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && MprisService.activePlayer)
                MprisService.activePlayer.togglePlaying();
            else AppState.toggleWidget("music");
        }
    }
}
