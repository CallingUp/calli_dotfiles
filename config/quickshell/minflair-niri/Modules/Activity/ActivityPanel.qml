import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Music
import qs.Modules.NotificationCenter

// The existing MPRIS/Cava and notification service remain the sole backends.
PanelWindow {
    id: activity
    required property var notificationService
    readonly property bool requested: AppState.activeWidget === "music" || AppState.activeWidget === "notificationsCenter"
    readonly property bool isOpen: requested
    property bool mappedReady: false
    property real progress: requested && mappedReady ? 1 : 0
    visible: requested || progress > 0
    onVisibleChanged: if (!visible) mappedReady = false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: requested ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "haku-activity"
    Behavior on progress {
        enabled: HyprlandService.enableAnimations
        NumberAnimation { duration: activity.requested ? 160 : 90; easing.type: activity.requested ? Easing.OutCubic : Easing.InQuad }
    }
    MouseArea { anchors.fill: parent; onClicked: AppState.closeAllWidgets() }
    Item {
        id: panel
        width: Math.min(460, activity.width - 32)
        height: Math.min(920, activity.height - 64)
        anchors.verticalCenter: parent.verticalCenter
        x: activity.width - width * activity.progress
        focus: activity.requested
        Keys.onEscapePressed: AppState.closeAllWidgets()
        Connections {
            target: panel.Window.window
            enabled: activity.requested && !activity.mappedReady
            function onFrameSwapped() {
                Qt.callLater(() => {
                    activity.mappedReady = true
                    panel.forceActiveFocus()
                })
            }
        }
        Rectangle { width: parent.width + 22; height: parent.height; radius: 22; color: "#08090b" }
        MouseArea { anchors.fill: parent }
        Loader {
            anchors.fill: parent
            anchors.margins: 20
            active: activity.visible
            sourceComponent: ColumnLayout {
                spacing: 18
                RowLayout {
                    Layout.fillWidth: true
                    ThemedText {
                        text: "Actividad"; color: Theme.accent
                        customSize: 17; font.bold: true
                        Layout.fillWidth: true
                    }
                    SvgIconButton {
                        icon: "x"; iconSize: 16; iconColor: Theme.accent
                        onClicked: AppState.closeAllWidgets()
                    }
                }
                ThemedText { text: "Reproducción"; customSize: 12; color: Theme.muted }
                ThemedText {
                    visible: activity.notificationService.automaticDnd
                    text: "Concentración · avisos guardados en el historial"
                    customSize: 11
                    color: Theme.accent
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                MiniMusicWidget {
                    id: player
                    prominentArt: true
                    widget: activity
                    playerWidth: panel.width - 40
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Theme.accent, 0.12) }
                NotificationCenter {
                    notificationService: activity.notificationService
                    controlCenterOpen: activity.requested
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 180
                }
            }
        }
    }
}
