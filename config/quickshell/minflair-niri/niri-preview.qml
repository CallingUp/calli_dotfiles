import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.Core
import qs.Core.Services
import qs.Modules.Bar.Styles.Island
import qs.Modules.Bar.Components

ShellRoot {
    id: root
    property bool barVisible: true
    onBarVisibleChanged: CavaService.barEnabled = barVisible
    property int cycleIndex: 0
    readonly property var islandPanels: ["music", "controlCenter", "powerMenu"]
    function dismissIsland() { island.pendingPanel = ""; island.close(); }
    function cycleIsland(delta) {
        if (HyprlandService.isTrueFullscreen) return;
        root.barVisible = true;
        const current = islandPanels.indexOf(AppState.activeWidget);
        cycleIndex = ((current >= 0 ? current : cycleIndex) + delta + islandPanels.length) % islandPanels.length;
        AppState.openWidget(islandPanels[cycleIndex]);
    }
    Connections {
        target: HyprlandService
        function onIsTrueFullscreenChanged() {
            if (HyprlandService.isTrueFullscreen) {
                island.closeImmediately();
                AppState.closeAllWidgets();
            }
        }
    }
    Component.onCompleted: { SettingsService.barStyle = "island"; SettingsService.fontFamily = "CommitMono Nerd Font"; }
    Connections {
        target: SettingsService
        function onSettingsLoadedChanged() { SettingsService.barStyle = "island"; SettingsService.fontFamily = "CommitMono Nerd Font"; }
    }
    NotificationService { id: notifications }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            const match = hakuColors.text().match(/@define-color\s+accent_color\s+(#[0-9a-fA-F]{6})/);
            if (match) Theme.accent = match[1];
        }
    }
    FileView {
        id: hakuColors
        path: Quickshell.env("HOME") + "/.local/state/haku_theme/colors.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const match = text().match(/@define-color\s+accent_color\s+(#[0-9a-fA-F]{6})/);
            if (match) Theme.accent = match[1];
        }
    }
    IpcHandler {
        target: "haku-media"
        function toggle() { AppState.toggleWidget("music"); }
        function open() { AppState.openWidget("music"); }
        function close() { root.dismissIsland(); }
    }
    IpcHandler {
        target: "haku-bar"
        function show() { root.barVisible = true; }
        function revealBar() { root.barVisible = true; }
        function hide() { island.closeImmediately(); AppState.closeAllWidgets(); root.barVisible = false; }
        function toggle() { if (root.barVisible) hide(); else show(); }
        function next() { root.cycleIsland(1); }
        function previous() { root.cycleIsland(-1); }
        function status(): string { return JSON.stringify({visible: root.barVisible, fullscreen: HyprlandService.isTrueFullscreen, mapped: surface.visible, panel: island.effectivePanel, pending: island.pendingPanel, open: island.isOpen}); }
    }
    IpcHandler {
        target: "widgets"
        function toggle(widget: string) { AppState.toggleWidget(widget); }
        function close() { root.dismissIsland(); }
    }
    PanelWindow {
        visible: root.barVisible && !HyprlandService.isTrueFullscreen
        anchors { top: true; left: true; right: true }
        implicitHeight: 44
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Auto
        mask: Region {}
    }
    PanelWindow {
        id: surface
        visible: root.barVisible && !HyprlandService.isTrueFullscreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: island.needsFocus && island.isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: Region {
            Region { x: 0; y: 0; width: surface.width; height: island.isOverlayActive ? surface.height : 0 }
            Region { x: island.centerX - 16; y: 0; width: island.centerWidth + 32; height: island.currentHeight + 20 }
            Region { x: 8; y: 4; width: workspaces.width; height: 36 }
            Region { x: power.x; y: 4; width: power.width; height: 36 }
            Region { x: tray.x; y: 4; width: tray.width; height: 36 }
        }
        MouseArea { anchors.fill: parent; enabled: island.isOverlayActive; onClicked: root.dismissIsland() }
        IslandBar {
            id: island
            x: 0; y: 0; width: surface.width
            notificationService: notifications
        }
        Workspaces { id: workspaces; x: 8; y: 10 }
        PowerButton { id: power; x: surface.width - width - 8; y: 8 }
        Row {
            id: tray
            x: power.x - width - 12; y: 10; spacing: 8
            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: trayIcon
                    required property var modelData
                    width: 22; height: 24
                    Image { anchors.fill: parent; source: modelData.icon; fillMode: Image.PreserveAspectFit }
                    QsMenuAnchor {
                        id: trayMenu
                        menu: trayIcon.modelData.menu
                        anchor.item: trayIcon
                        anchor.rect.y: trayIcon.height
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton || trayIcon.modelData.onlyMenu) trayMenu.open();
                            else trayIcon.modelData.activate();
                        }
                    }
                }
            }
        }
    }
}
