import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // It starts visible when launched as the future bar service. Keeping it
    // here also makes a reload deterministic while Waybar is still staged.
    property bool barVisible: true
    readonly property bool islandOverlayActive: dynamicIsland.visible // Single shared Minflair-style island surface.

    IpcHandler {
        target: "haku-media"

        function toggle() { dynamicIsland.toggleTarget("media"); }
        function open() { dynamicIsland.openTarget("media"); }
        function close() { dynamicIsland.close(); }
    }

    IpcHandler {
        target: "haku-island"
        function toggleLeft() { dynamicIsland.toggleTarget("left"); }
        function toggleMedia() { dynamicIsland.toggleTarget("media"); }
        function toggleSystem() { dynamicIsland.toggleTarget("system"); }
        function close() { dynamicIsland.close(); }
    }

    IpcHandler {
        target: "haku-bar"

        function show() { root.barVisible = true; }
        function hide() { dynamicIsland.close(); root.barVisible = false; }
        function toggle() { if (root.barVisible) hide(); else show(); }
    }

    HakuBar {
        id: hakuBar
        barVisible: root.barVisible
        cavaLevels: cavaSource.levels
        islandTarget: dynamicIsland.target
        islandProgress: dynamicIsland.progress
        onIslandRequested: dynamicIsland.toggleTarget(target)
        onFullscreenChanged: if (fullscreen) dynamicIsland.close()
    }

    CavaSource {
        id: cavaSource
        active: root.barVisible && !hakuBar.fullscreen
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
            onClicked: dynamicIsland.close()
        }

        HakuDynamicIsland {
            id: dynamicIsland
            accentHex: hakuBar.accentHex
            summary: hakuBar.systemSummary
            activePlayer: hakuBar.activePlayer
            cavaLevels: cavaSource.levels
            activeWorkspace: hakuBar.activeWorkspace
            workspaceCount: hakuBar.workspaceCount()
            mediaX: hakuBar.mediaCapsuleX
            mediaWidth: hakuBar.mediaCapsuleWidth
            systemRightX: hakuBar.systemCapsuleRightX
            systemWidth: hakuBar.systemCapsuleWidth
            leftX: hakuBar.leftCapsuleX
            leftWidth: hakuBar.leftCapsuleWidth
        }
    }
}
