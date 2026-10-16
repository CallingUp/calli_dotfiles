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
import qs.Modules.WallpaperCarousel as Wallpaper
import qs.Modules.Shortcuts as Shortcuts
import qs.Modules.Clipboard as Clipboard

ShellRoot {
    id: root
    property bool clipboardOpen: false
    IpcHandler {
        target: "haku-clipboard-host"
        function toggle() {
            root.clipboardOpen = !root.clipboardOpen;
            if (root.clipboardOpen) {
                root.dismissIsland();
                root.shortcutsOpen = false;
                root.closeWallpaper();
            }
        }
        function close() { root.clipboardOpen = false; }
        function status(): string { return clipboardLoader.item ? "open" : "closed"; }
    }
    Loader {
        id: clipboardLoader
        active: root.clipboardOpen
        sourceComponent: Component {
            Clipboard.Clipboard { hosted: true; onCloseRequested: root.clipboardOpen = false }
        }
    }
    property bool shortcutsOpen: false
    IpcHandler {
        target: "haku-shortcuts-host"
        function toggle() {
            root.shortcutsOpen = !root.shortcutsOpen;
            if (root.shortcutsOpen) {
                root.dismissIsland();
                root.clipboardOpen = false;
                root.closeWallpaper();
            }
        }
        function close() { root.shortcutsOpen = false; }
        function status(): string { return shortcutsLoader.item ? "open" : "closed"; }
    }
    Loader {
        id: shortcutsLoader
        active: root.shortcutsOpen
        sourceComponent: Component {
            Shortcuts.Shortcuts { onCloseRequested: root.shortcutsOpen = false }
        }
    }
    // The carousel is instantiated only while open, sharing this renderer.
    property var wallpaperRequest: null
    function closeWallpaper() {
        if (wallpaperLoader.item) wallpaperLoader.item.requestClose();
        else wallpaperRequest = null;
    }
    IpcHandler {
        target: "haku-wallpaper-host"
        function toggle(request: string) {
            if (root.wallpaperRequest !== null) {
                root.closeWallpaper();
                return;
            }
            root.dismissIsland();
            root.shortcutsOpen = false;
            root.clipboardOpen = false;
            root.wallpaperRequest = JSON.parse(request);
        }
        function close() { root.closeWallpaper(); }
        function status(): string {
            return wallpaperLoader.item ? "open" : "closed";
        }
        function step(delta: int) {
            if (wallpaperLoader.item) wallpaperLoader.item.navigate(delta);
        }
    }
    Loader {
        id: wallpaperLoader
        active: root.wallpaperRequest !== null
        sourceComponent: Component {
            Wallpaper.Carousel {
                initialSettings: root.wallpaperRequest
                onCloseRequested: root.wallpaperRequest = null
            }
        }
    }
    // Keyboard show pins all sections; otherwise only the hovered section opens.
    property bool barVisible: false
    readonly property real islandSpacing: Math.min(320, surface.width / 4)
    property var selectedTrayItem: null
    property var displayedTrayItem: null
    property real trayProgress: selectedTrayItem !== null ? 1 : 0
    onSelectedTrayItemChanged: {
        if (selectedTrayItem !== null) displayedTrayItem = selectedTrayItem;
    }
    onTrayProgressChanged: {
        if (trayProgress === 0 && selectedTrayItem === null)
            displayedTrayItem = null;
    }
    Behavior on trayProgress {
        enabled: HyprlandService.enableAnimations
        NumberAnimation { duration: root.selectedTrayItem !== null ? 260 : 180; easing.type: Easing.OutCubic }
    }
    readonly property bool barRequested: centerReveal.requested || rightReveal.requested || statsReveal.requested
    readonly property real barProgress: Math.max(centerReveal.progress, rightReveal.progress, statsReveal.progress)
    Binding {
        target: SystemInfoService
        property: "barClockVisible"
        value: surface.visible && centerReveal.progress > 0
    }
    Binding {
        target: SystemStats
        property: "barStatsVisible"
        value: surface.visible && statsReveal.progress > 0
    }
    EdgeReveal {
        id: statsReveal
        allowed: !HyprlandService.isTrueFullscreen
        pinned: root.barVisible
        hovered: statsEdge.hovered || statsIsland.hovered
        animationsEnabled: HyprlandService.enableAnimations
    }
    EdgeReveal {
        id: centerReveal
        allowed: !HyprlandService.isTrueFullscreen
        pinned: root.barVisible
        hovered: centerEdge.hovered || centerHover.hovered
        holdOpen: island.isOverlayActive || island.hasActiveNotifications
        keyboardHold: island.isOpen && island.needsFocus
        animationsEnabled: HyprlandService.enableAnimations
        onDismissRequested: if (island.isOverlayActive) root.dismissIsland()
    }
    EdgeReveal {
        id: rightReveal
        allowed: !HyprlandService.isTrueFullscreen
        pinned: root.barVisible
        hovered: rightEdge.hovered || trayHover.hovered
        holdOpen: root.selectedTrayItem !== null || root.trayProgress > 0
        animationsEnabled: HyprlandService.enableAnimations
        onDismissRequested: root.selectedTrayItem = null
    }
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
        root.barVisible = false;
        cycleIndex = (cycleIndex + delta + islandPanels.length) % islandPanels.length;
        if (cycleIndex === 1) statsReveal.revealNow();
        else centerReveal.revealNow();
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
    FileView {
        id: hakuColors
        path: Quickshell.env("HOME") + "/.local/state/haku_theme/colors.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const match = text().match(/@define-color\s+accent_color\s+(#[0-9a-fA-F]{6})/);
            if (match && !Theme.fixedPaletteEnabled) Theme.accent = match[1];
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
                centerReveal.revealNow();
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
                centerReveal.revealNow();
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
                centerReveal.revealNow();
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
        function hide() {
            island.closeImmediately(); AppState.closeAllWidgets(); root.selectedTrayItem = null;
            root.barVisible = false;
            centerReveal.hideNow(); rightReveal.hideNow();
            statsReveal.hideNow();
        }
        function toggle() { if (root.barVisible) hide(); else show(); }
        function next() { root.cycleIsland(1); }
        function previous() { root.cycleIsland(-1); }
        function peek(section: string) {
            if (section === "stats") statsReveal.revealNow();
            else if (section === "center") centerReveal.revealNow();
            else if (section === "right") rightReveal.revealNow();
        }
        function status(): string { return JSON.stringify({visible: root.barVisible, fullscreen: HyprlandService.isTrueFullscreen, mapped: surface.visible, reserved: false, inputEnabled: barContent.enabled && surface.visible, panel: island.effectivePanel, pending: island.pendingPanel, open: island.isOpen, edgeMode: true, left: 0, center: centerReveal.progress, right: rightReveal.progress, stats: statsReveal.progress, statsNeeded: SystemStats.statsNeeded}); }
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
        id: surface
        visible: !HyprlandService.isTrueFullscreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.barRequested && island.needsFocus && island.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region {
            Region { item: centerEdge }
            Region { item: rightEdge }
            Region { item: statsEdge }
            Region { x: statsIsland.x; y: statsIsland.y; width: statsReveal.requested ? statsIsland.width : 0; height: statsIsland.height }
            Region { x: 0; y: 0; width: surface.width; height: root.barRequested && (island.isOverlayActive || root.selectedTrayItem !== null) ? surface.height : 0 }
            Region { x: island.centerX - 16; y: centerContainer.y; width: centerReveal.requested ? island.centerWidth + 32 : 0; height: island.currentHeight + 20 }
            Region { x: trayBackground.x; y: trayBackground.y; width: rightReveal.requested ? trayBackground.width : 0; height: trayBackground.height }
        }
        MouseArea { anchors.fill: parent; enabled: island.isOverlayActive || root.selectedTrayItem !== null; onClicked: root.dismissIsland() }
        Item {
            id: barContent
            width: surface.width; height: surface.height
            // Keep exit frames, then stop drawing the hidden island subtree.
            // Edge handles live outside this item and remain interactive.
            visible: root.barRequested || root.barProgress > 0
            enabled: root.barRequested
        Item {
            id: centerContainer
            width: surface.width; height: surface.height
            y: -44 * (1 - centerReveal.progress)
        IslandBar {
            id: island
            x: 0; y: 0; width: surface.width
            notificationService: notifications
        }
        Item {
            x: island.centerX - 16; y: 0
            width: island.centerWidth + 32; height: island.currentHeight + 20
            HoverHandler { id: centerHover; blocking: false }
        }
        }
        StatsIsland {
            id: statsIsland
            x: surface.width / 2 - root.islandSpacing - width / 2
            y: -40 * (1 - statsReveal.progress)
        }
        IslandBackground {
            id: trayBackground
            readonly property real compactWidth: tray.implicitWidth > 0 ? tray.implicitWidth + 20 : 0
            x: surface.width / 2 + root.islandSpacing - width / 2
            y: -40 * (1 - rightReveal.progress)
            width: compactWidth + (Math.max(300, compactWidth) - compactWidth) * root.trayProgress
            height: 32 + Math.min(380, surface.height - 76) * root.trayProgress
            radius: Constants.sizeLg
            visible: width > 0
            clip: true
            z: 20
            HoverHandler { id: trayHover; blocking: false }
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
                    Image { anchors.centerIn: parent; width: 20; height: 20; source: modelData.icon; sourceSize: Qt.size(40, 40); asynchronous: true; fillMode: Image.PreserveAspectFit }
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
        EdgeHandle { id: centerEdge; x: (surface.width - width) / 2; width: 180; accent: Theme.accent; revealProgress: centerReveal.progress }
        EdgeHandle { id: statsEdge; x: statsIsland.x + (statsIsland.width - width) / 2; width: 96; accent: Theme.accent; revealProgress: statsReveal.progress }
        EdgeHandle { id: rightEdge; x: surface.width / 2 + root.islandSpacing - width / 2; width: 96; accent: Theme.accent; revealProgress: rightReveal.progress }
    }
}
