//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.Core
import qs.Core.Services
import qs.Modules.Bar.Styles.Island
import qs.Modules.Bar.Components
import qs.Modules.Bar.Widgets.SystemTray as TrayWidgets
import qs.Modules.Activity

ShellRoot {
    id: root
    property bool barVisible: true
    property var selectedTrayItem: null
    property var displayedTrayItem: null
    property real trayProgress: selectedTrayItem !== null ? 1 : 0
    onSelectedTrayItemChanged: {
        if (selectedTrayItem !== null) displayedTrayItem = selectedTrayItem;
    }
    Behavior on trayProgress {
        enabled: HyprlandService.enableAnimations
        NumberAnimation { duration: root.selectedTrayItem !== null ? 260 : 180; easing.type: Easing.OutCubic }
    }
    readonly property bool barRequested: barVisible && !HyprlandService.isTrueFullscreen
    property real barProgress: barRequested ? 1 : 0
    Behavior on barProgress {
        enabled: HyprlandService.enableAnimations
        NumberAnimation {
            duration: root.barRequested ? 160 : 90
            easing.type: root.barRequested ? Easing.OutCubic : Easing.InQuad
        }
    }
    onBarVisibleChanged: CavaService.barEnabled = barVisible
    onBarRequestedChanged: {
        if (!barRequested) {
            selectedTrayItem = null;
            if (AppState.activeWidget === "music" || AppState.activeWidget === "notificationsCenter")
                AppState.closeAllWidgets();
        }
    }
    property int cycleIndex: 0
    readonly property var islandPanels: ["", "stats"]
    function dismissIsland() { selectedTrayItem = null; island.dismiss(); }
    function cycleIsland(delta) {
        if (HyprlandService.isTrueFullscreen) return;
        root.barVisible = true;
        const current = islandPanels.indexOf(AppState.activeWidget);
        cycleIndex = ((current >= 0 ? current : cycleIndex) + delta + islandPanels.length) % islandPanels.length;
        if (islandPanels[cycleIndex] === "")
            AppState.closeAllWidgets();
        else
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
    NotificationService { id: notifications; nativeNotificationsEnabled: true }
    ActivityPanel { notificationService: notifications }
    IpcHandler {
        target: "haku-activity"
        function toggle() {
            if (AppState.activeWidget === "music" || AppState.activeWidget === "notificationsCenter")
                AppState.closeAllWidgets();
            else if (!HyprlandService.isTrueFullscreen) {
                root.barVisible = true;
                root.selectedTrayItem = null;
                AppState.openWidget("music");
            }
        }
        function close() { AppState.closeWidget("music"); AppState.closeWidget("notificationsCenter"); }
    }
    IpcHandler {
        target: "haku-osd"
        function displayOsd(label: string, value: string, icon: string) {
            if (label === "Volume" || label === "Brightness")
                notifications.notify(label, value, icon, "Haku");
        }
    }
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
        target: "haku-controls"
        function setCaffeine(enabled: bool) { DisplayProfileService.caffeineActive = enabled; }
        function status(): string {
            return JSON.stringify({
                caffeine: DisplayProfileService.caffeineActive,
                caffeineSurface: caffeineSurface.visible,
                caffeineError: DisplayProfileService.caffeineError,
                nightLight: DisplayProfileService.nightLightActive,
                nightLightError: DisplayProfileService.nightLightError,
                gameMode: DisplayProfileService.gameModeActive,
                gameModeBusy: DisplayProfileService.gameModeBusy,
                gameModeError: DisplayProfileService.gameModeError
            });
        }
        function toggleControls() {
            if (AppState.activeWidget === "controlCenter") root.dismissIsland();
            else {
                root.selectedTrayItem = null;
                root.barVisible = true;
                AppState.openWidget("controlCenter");
            }
        }
    }
    IpcHandler {
        target: "haku-power"
        function togglePower() {
            if (AppState.activeWidget === "powerMenu") root.dismissIsland();
            else {
                root.selectedTrayItem = null;
                root.barVisible = true;
                AppState.openWidget("powerMenu");
            }
        }
    }
    IpcHandler {
        target: "haku-launcher"
        function toggleLauncher() {
            if (AppState.activeWidget === "launcher") {
                root.dismissIsland();
            } else {
                root.selectedTrayItem = null;
                root.barVisible = true;
                AppState.openWidget("launcher");
            }
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
        function status(): string { return JSON.stringify({visible: root.barVisible, fullscreen: HyprlandService.isTrueFullscreen, mapped: surface.visible, reserved: reservation.visible, inputEnabled: barContent.enabled && surface.visible, panel: island.effectivePanel, pending: island.pendingPanel, open: island.isOpen}); }
    }
    IpcHandler {
        target: "widgets"
        function toggle(widget: string) { AppState.toggleWidget(widget); }
        function close() { root.dismissIsland(); }
    }
    // Separate background surface: caffeine must work with a hidden bar/fullscreen.
    PanelWindow {
        id: caffeineSurface
        visible: DisplayProfileService.caffeineActive
        anchors { bottom: true; left: true }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        WlrLayershell.namespace: "haku-caffeine"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        IdleInhibitor {
            window: caffeineSurface
            enabled: DisplayProfileService.caffeineActive
        }
    }
    PanelWindow {
        id: reservation
        visible: (root.barRequested || root.barProgress > 0) && !HyprlandService.isTrueFullscreen
        anchors { top: true; left: true; right: true }
        // Keep a fixed reservation throughout the slide; release it only on unmap.
        implicitHeight: 44
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Auto
        mask: Region {}
    }
    PanelWindow {
        id: surface
        visible: (root.barRequested || root.barProgress > 0) && !HyprlandService.isTrueFullscreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.barRequested && island.needsFocus && island.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region {
            Region { x: 0; y: 0; width: surface.width; height: root.barRequested && (island.isOverlayActive || root.selectedTrayItem !== null) ? surface.height : 0 }
            Region { x: island.centerX - 16; y: barContent.y; width: root.barRequested ? island.centerWidth + 32 : 0; height: island.currentHeight + 20 }
            Region { x: workspaceBackground.x; y: barContent.y; width: root.barRequested ? workspaceBackground.width : 0; height: 32 }
            Region { x: trayBackground.x; y: barContent.y; width: root.barRequested ? trayBackground.width : 0; height: trayBackground.height }
        }
        MouseArea { anchors.fill: parent; enabled: island.isOverlayActive || root.selectedTrayItem !== null; onClicked: root.dismissIsland() }
        Item {
            id: barContent
            width: surface.width; height: surface.height
            y: -44 * (1 - root.barProgress)
            enabled: root.barRequested
        IslandBar {
            id: island
            x: 0; y: 0; width: surface.width
            notificationService: notifications
        }
        IslandBackground {
            id: workspaceBackground
            x: 8; y: 0
            width: workspaces.implicitWidth + 20; height: 32; radius: Constants.sizeLg
            Workspaces { id: workspaces; anchors.centerIn: parent; customHeight: 32; bgColor: "transparent" }
        }
        IslandBackground {
            id: trayBackground
            readonly property real compactWidth: tray.implicitWidth > 0 ? tray.implicitWidth + 20 : 0
            x: surface.width - width - 8; y: 0
            width: compactWidth + (Math.max(300, compactWidth) - compactWidth) * root.trayProgress
            height: 32 + Math.min(380, surface.height - 76) * root.trayProgress
            radius: Constants.sizeLg
            visible: width > 0
            clip: true
            z: 20
            MouseArea { anchors.fill: parent; enabled: root.trayProgress > 0; onClicked: root.selectedTrayItem = null }
        Row {
            id: tray
            anchors.top: parent.top; anchors.topMargin: 4
            anchors.right: parent.right; anchors.rightMargin: 10
            spacing: 8
            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: trayIcon
                    required property var modelData
                    width: 24; height: 24
                    Image { anchors.centerIn: parent; width: 20; height: 20; source: modelData.icon; fillMode: Image.PreserveAspectFit }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (trayIcon.modelData.hasMenu) {
                                const next = root.selectedTrayItem === trayIcon.modelData ? null : trayIcon.modelData;
                                island.dismiss();
                                root.selectedTrayItem = next;
                            } else trayIcon.modelData.activate();
                        }
                    }
                }
            }
        }
        Loader {
            x: 12; y: 42
            width: Math.max(300, trayBackground.compactWidth) - 24
            height: Math.min(380, surface.height - 76) - 22
            active: root.trayProgress > 0
            opacity: Math.max(0, (root.trayProgress - 0.3) / 0.7)
            enabled: root.selectedTrayItem !== null && root.trayProgress > 0.95
            sourceComponent: TrayWidgets.TrayMenu {
                applicationIcon: root.displayedTrayItem ? root.displayedTrayItem.icon.toString() : ""
                menuHandle: root.displayedTrayItem ? root.displayedTrayItem.menu : null
                title: root.displayedTrayItem ? (root.displayedTrayItem.title || root.displayedTrayItem.id || "Menú") : ""
                onCloseRequested: root.selectedTrayItem = null
                onBackRequested: root.selectedTrayItem = null
            }
        }
        }
        }
    }
}
