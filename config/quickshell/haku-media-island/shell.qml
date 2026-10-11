import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // It starts visible when launched as the future bar service. Keeping it
    // here also makes a reload deterministic while Waybar is still staged.
    property bool barVisible: true
    readonly property bool islandOverlayActive: island.visible || systemIsland.visible

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
        mediaIslandOpen: island.visible
        systemIslandOpen: systemIsland.visible
        onMediaRequested: island.open = !island.open
        onSystemRequested: systemIsland.open = !systemIsland.open
        onFullscreenChanged: if (fullscreen) { island.open = false; systemIsland.open = false; }
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
        WlrLayershell.layer: root.islandOverlayActive ? WlrLayer.Overlay : WlrLayer.Top
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
                width: root.islandOverlayActive ? surface.width : 0
                height: root.islandOverlayActive ? surface.height : 0
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.islandOverlayActive
            onClicked: { island.open = false; systemIsland.open = false; }
        }

        MediaIsland {
            id: island
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 7
            collapsedWidth: hakuBar.mediaCapsuleWidth
        }

        SystemIsland {
            id: systemIsland
            // Preserve its right edge as it expands, like a native right
            // island. That keeps it inside the screen beside tray/power.
            x: hakuBar.systemCapsuleX - (systemIsland.expandedWidth - hakuBar.systemCapsuleWidth) * systemIsland.progress
            y: 7
            collapsedWidth: hakuBar.systemCapsuleWidth
            accentHex: hakuBar.accentHex
            summary: hakuBar.systemSummary
        }
    }
}
