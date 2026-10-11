import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // It starts visible when launched as the future bar service. Keeping it
    // here also makes a reload deterministic while Waybar is still staged.
    property bool barVisible: true

    IpcHandler {
        target: "haku-media"

        function toggle() { island.open = !island.open; }
        function open() { island.open = true; }
        function close() { island.open = false; }
    }

    IpcHandler {
        target: "haku-bar"

        function show() { root.barVisible = true; }
        function hide() { island.open = false; root.barVisible = false; }
        function toggle() { if (root.barVisible) hide(); else show(); }
    }

    HakuBar {
        id: hakuBar
        barVisible: root.barVisible
        onMediaRequested: island.open = !island.open
    }

    PanelWindow {
        id: surface

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        focusable: false
        // Only rise above the compact Waybar trigger while the island is
        // actually animating. When closed it renders nothing at all.
        WlrLayershell.layer: island.visible ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // A transparent PanelWindow otherwise owns its entire 312px surface
        // for input. Restrict pointer events to the actual island only.
        mask: Region {
            Region {
                // While expanded, consume one outside click to close. Once it
                // is closed the input area becomes zero again, so apps retain
                // normal pointer access everywhere.
                x: 0
                y: 0
                width: island.visible ? surface.width : 0
                height: island.visible ? surface.height : 0
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: island.visible
            onClicked: island.open = false
        }

        MediaIsland {
            id: island
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 5
        }
    }
}
