import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    IpcHandler {
        target: "haku-media"

        function toggle() { island.open = !island.open; }
        function open() { island.open = true; }
        function close() { island.open = false; }
    }

    PanelWindow {
        id: surface

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 312
        color: "transparent"
        focusable: false
        // Only rise above the compact Waybar trigger while the island is
        // actually animating. When closed it renders nothing at all.
        WlrLayershell.layer: island.visible ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MediaIsland {
            id: island
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 5
        }
    }
}
