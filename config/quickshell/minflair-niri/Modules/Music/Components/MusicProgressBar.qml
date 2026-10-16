import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Core
import qs.Core.Components
import qs.Core.Services

ColumnLayout {
    id: progressRoot

    property bool isVisibleOnScreen: true
    readonly property var player: MprisService.activePlayer
    // MprisPlayer.length falls back to position when duration is unsupported.
    readonly property bool hasDuration: player !== null && MprisService.timelineDuration > 0
    readonly property real duration: hasDuration ? MprisService.timelineDuration : 0
    readonly property bool hasPosition: player !== null && player.positionSupported
    readonly property real elapsed: hasPosition && Number.isFinite(player.position)
                                    ? Math.max(0, hasDuration ? Math.min(duration, player.position) : player.position) : 0

    Layout.fillWidth: true
    spacing: Constants.size3Xs
    Layout.topMargin: Constants.size3Xs

    Item {
        id: progressArea

        readonly property real rawProgress: progressRoot.hasDuration && progressRoot.hasPosition
                                            ? progressRoot.elapsed / progressRoot.duration : 0
        property real seekProgress: 0
        readonly property real currentProgress: seekMouseArea.pressed ? seekProgress : Math.max(0, Math.min(1, rawProgress))
        property real lastRawProgress: 0
        property bool isDiscontinuous: false
        readonly property bool isInteractive: seekMouseArea.containsMouse || seekMouseArea.pressed
        readonly property real trackHeight: isInteractive ? 5 : 3

        onRawProgressChanged: {
            let diff = rawProgress - lastRawProgress;
            if (diff < 0 || diff > 0.04) {
                isDiscontinuous = true;
                discontinuousTimer.restart();
            }
            lastRawProgress = rawProgress;
        }
        Layout.fillWidth: true
        Layout.preferredHeight: Constants.sizeMd

        Timer {
            id: discontinuousTimer

            interval: 50
            onTriggered: progressArea.isDiscontinuous = false
        }

        // Background Track
        Rectangle {
            id: bgTrack

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: progressArea.trackHeight
            radius: height / 2
            color: Theme.fg
            opacity: 0.15

            Behavior on height {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutQuad
                }

            }

        }

        // Active Elapsed Progress
        Rectangle {
            id: activeTrack

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: progressArea.trackHeight
            radius: height / 2
            color: Theme.accent
            width: Math.max(0, Math.min(parent.width, progressArea.currentProgress * parent.width))

            Behavior on height {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutQuad
                }

            }

            Behavior on width {
                enabled: !seekMouseArea.pressed && MprisService.isPlaying && progressRoot.isVisibleOnScreen && !progressArea.isDiscontinuous

                NumberAnimation {
                    duration: Constants.animExpressive * 2
                    easing.type: Easing.Linear
                }

            }

        }

        // Playhead Thumb / Handle
        Rectangle {
            id: thumb

            x: Math.max(0, Math.min(parent.width - width, (progressArea.currentProgress * parent.width) - (width / 2)))
            anchors.verticalCenter: parent.verticalCenter
            width: seekMouseArea.pressed ? 12 : (seekMouseArea.containsMouse ? 10 : 6)
            height: width
            radius: width / 2
            color: Theme.accent
            visible: progressRoot.hasDuration && progressRoot.hasPosition
            scale: progressArea.currentProgress > 0.001 ? 1 : 0
            layer.enabled: progressArea.isInteractive

            Behavior on width {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutQuad
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutBack
                }

            }

            Behavior on x {
                enabled: !seekMouseArea.pressed && MprisService.isPlaying && progressRoot.isVisibleOnScreen && !progressArea.isDiscontinuous

                NumberAnimation {
                    duration: Constants.animExpressive * 2
                    easing.type: Easing.Linear
                }

            }

            layer.effect: DropShadow {
                transparentBorder: true
                color: Theme.accent
                radius: Constants.size2Xs + 2
                samples: 13
                opacity: 0.4
            }

        }

        MouseArea {
            id: seekMouseArea

            function updateSeek(mouse) {
                if (!progressRoot.hasDuration || !progressRoot.hasPosition || !progressRoot.player.canSeek)
                    return ;

                var p = Math.max(0, Math.min(1, mouse.x / width));
                progressArea.seekProgress = p;
            }

            anchors.fill: parent
            enabled: progressRoot.hasDuration && progressRoot.hasPosition && progressRoot.player.canSeek
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: (mouse) => {
                updateSeek(mouse);
            }
            onReleased: {
                if (progressRoot.hasDuration && progressRoot.hasPosition)
                    MprisService.seekTo(progressArea.seekProgress * progressRoot.duration);
            }
            onPositionChanged: (mouse) => {
                if (pressed)
                    updateSeek(mouse);

            }
        }

    }

    RowLayout {
        Layout.fillWidth: true

        ThemedText {
            text: {
                if (seekMouseArea.pressed && progressRoot.hasDuration)
                    return MprisService.formatTime(progressArea.seekProgress * progressRoot.duration);

                return progressRoot.hasPosition ? MprisService.formatTime(progressRoot.elapsed) : "--:--";
            }
            customSize: Constants.sizeXs
            color: Theme.muted
        }

        Item {
            Layout.fillWidth: true
        }

        ThemedText {
            text: progressRoot.hasDuration ? MprisService.formatTime(progressRoot.duration) : "--:--"
            customSize: Constants.sizeXs
            color: Theme.muted
        }

    }

}
