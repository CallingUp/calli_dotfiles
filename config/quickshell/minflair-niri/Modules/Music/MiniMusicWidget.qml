import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Music.Components

Item {
    id: root

    property var widget: null
    property bool prominentArt: false
    readonly property real artSize: prominentArt ? Math.min(144, playerWidth * 0.35) : metadataColumn.implicitHeight
    property real playerWidth: 410
    readonly property bool isVisibleOnScreen: widget !== null && widget.isOpen !== undefined ? widget.isOpen : true

    implicitWidth: playerWidth
    implicitHeight: mainRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    ColumnLayout {
        id: mainRow

        anchors.fill: parent
        spacing: Constants.sizeMd

        RowLayout {
            id: playerColumn

            Layout.preferredWidth: root.playerWidth
            Layout.fillWidth: false
            Layout.fillHeight: false
            spacing: Constants.sizeLg

            // COVER ART
            Item {
                id: artSection

                Layout.preferredWidth: root.artSize
                Layout.preferredHeight: root.artSize
                Layout.alignment: Qt.AlignHCenter

                Image {
                    id: artImage

                    anchors.fill: parent
                    source: MprisService.activePlayer ? (MprisService.activePlayer.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    // Decode for the largest displayed size, not the full cover.
                    sourceSize: Qt.size(Math.ceil(root.artSize * Math.min(2, Screen.devicePixelRatio)), Math.ceil(root.artSize * Math.min(2, Screen.devicePixelRatio)))
                    mipmap: false
                    asynchronous: true
                    visible: false
                }

                Rectangle {
                    id: artMask

                    anchors.fill: parent
                    radius: Constants.sizeLg
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: artImage
                    maskSource: artMask
                    visible: artImage.status === Image.Ready && MprisService.activePlayer !== null
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Constants.sizeLg
                    color: Theme.bgSecondary
                    visible: artImage.status !== Image.Ready || MprisService.activePlayer === null

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "music"
                        iconSize: parent.width * 0.4
                        iconColor: Theme.accent
                        flat: true
                    }

                }

            }

            // METADATA
            ColumnLayout {
                id: metadataColumn

                Layout.fillWidth: true
                spacing: Constants.size2Xs

                TypewriterText {
                    text: MprisService.activePlayer ? (MprisService.activePlayer.trackTitle || "Not Playing") : "No Music"
                    customSize: Constants.sizeMd
                    font.weight: Font.Bold
                    color: Theme.fg
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                TypewriterText {
                    text: MprisService.activePlayer ? (MprisService.activePlayer.trackArtist || "Unknown Artist") : "Open a music player to get started"
                    customSize: Constants.sizeSm
                    color: Theme.accentComplementary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                MusicProgressBar {
                }

                // CONTROLS
                MusicPlayerControls {
                    currentLoopState: {
                        if (!MprisService.activePlayer || !MprisService.activePlayer.loopSupported)
                            return 0;

                        return MprisService.activePlayer.loopState;
                    }
                    isShuffleActive: {
                        if (!MprisService.activePlayer || !MprisService.activePlayer.shuffleSupported)
                            return false;

                        return MprisService.activePlayer.shuffle;
                    }
                }

            }

        }

    }

}
