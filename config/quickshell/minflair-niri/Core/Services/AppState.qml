import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Services
pragma Singleton

Item {
    id: appState

    property string activeWidget: ""
    property var activeWidgetsList: []
    readonly property bool isFocusWidgetOpen: isWidgetOpen("launcher") || isWidgetOpen("clipboard") || isWidgetOpen("wallpaper") || isWidgetOpen("powerMenu") || isWidgetOpen("screenshot")
    property int pendingSettingsTab: -1
    property var launcherApps: []
    property var launcherUsage: ({})

    FileView {
        id: launcherUsageFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/haku-launcher-usage.json"
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                appState.launcherUsage = data && typeof data === "object" && !Array.isArray(data) ? data : {};
            } catch (error) {
                console.warn("Invalid launcher usage history; starting empty");
                appState.launcherUsage = {};
            }
        }
    }

    function recordLauncherUse(desktopId) {
        if (!desktopId) return;
        const usage = Object.assign({}, launcherUsage);
        usage[desktopId] = (Number(usage[desktopId]) || 0) + 1;
        launcherUsage = usage;
        launcherUsageFile.setText(JSON.stringify(usage));
    }
    property bool socketsCleaned: true
    property real islandWidth: 180
    property real islandHeight: Constants.size3Xl
    property alias barIslandWidth: appState.islandWidth
    property alias barIslandHeight: appState.islandHeight
    property bool isIslandOpen: false
    property bool isConvexOpen: false
    property real barConvexWidth: 220
    property real barConvexHeight: Constants.size4Xl
    property var activeTrayItem: null
    property bool hasActiveNotification: false
    property real activeNotificationWidth: 0
    property real activeNotificationHeight: 0
    readonly property var focusWidgets: ["launcher", "clipboard", "wallpaper", "screenshot", "powerMenu"]
    readonly property var standaloneWindows: ["minflair_settings", "minflair_keybinds", "packagemanager"]

    signal toggleWidget(string widgetId)
    signal openWidget(string widgetId)

    function isBarWidget(id) {
        if (!id)
            return false;

        return id === "stats" || id === "dashboard" || id === "controlCenter" || id === "notificationsCenter" || id === "music" || id === "clock" || id.startsWith("systemTray_");
    }

    function isFocusWidget(id) {
        return focusWidgets.indexOf(id) !== -1;
    }

    function isBarOverlayWidget(id) {
        return isFocusWidget(id) || isBarWidget(id);
    }

    function isStandaloneWindow(id) {
        return standaloneWindows.indexOf(id) !== -1;
    }

    function isWidgetOpen(id) {
        if (!id || isStandaloneWindow(id))
            return false;

        if (activeWidget === id)
            return true;

        return activeWidgetsList.indexOf(id) !== -1;
    }

    function getSlot(widgetId, barStyle) {
        if (isFocusWidget(widgetId))
            return "focus";

        let s = barStyle || SettingsService.barStyle;
        if (s === "island")
            return "center";

        // convex
        if (widgetId === "dashboard")
            return "left";

        if (widgetId === "music")
            return "center";

        if (widgetId === "controlCenter" || widgetId === "notificationsCenter" || widgetId === "clock" || widgetId.startsWith("systemTray_"))
            return "right";

        return widgetId;
    }

    function closeWidget(widgetId) {
        if (!widgetId)
            return ;

        if (widgetId.startsWith("systemTray_") || activeWidget === widgetId)
            activeTrayItem = null;

        let idx = activeWidgetsList.indexOf(widgetId);
        if (idx !== -1) {
            let next = activeWidgetsList.slice();
            next.splice(idx, 1);
            activeWidgetsList = next;
        }
        if (activeWidget === widgetId)
            activeWidget = "";

    }

    function closeAllWidgets() {
        activeTrayItem = null;
        activeWidgetsList = [];
        activeWidget = "";
    }

    function openWidgetInternal(widgetId) {
        if (widgetId === "packageManager" && Quickshell.env("HAKU_PACKAGE_BACKEND") === "disabled") {
            console.warn("Haku: el gestor integrado requiere Arch; usa el gestor de tu distribución.");
            return;
        }
        if (!widgetId || isStandaloneWindow(widgetId))
            return ;

        // Island mode has one expanded surface, never a hidden stack of panels.
        if (SettingsService.barIslandMode && isBarOverlayWidget(widgetId)) {
            activeWidgetsList = [widgetId];
            activeWidget = widgetId;
            return;
        }

        let slot = getSlot(widgetId);
        // Rule 1: Focus widgets close each other, but do NOT close bar widgets
        if (slot === "focus") {
            let next = [];
            for (let i = 0; i < activeWidgetsList.length; i++) {
                let item = activeWidgetsList[i];
                if (isFocusWidget(item))
                    continue;

                next.push(item);
            }
            next.push(widgetId);
            activeWidgetsList = next;
            activeWidget = widgetId;
            return ;
        }
        // Rule 2: Opening a bar widget closes widgets in the same slot, but keeps focus widgets open
        let next = [];
        for (let i = 0; i < activeWidgetsList.length; i++) {
            let item = activeWidgetsList[i];
            if (getSlot(item) === slot)
                continue;

            next.push(item);
        }
        if (next.indexOf(widgetId) === -1)
            next.push(widgetId);

        activeWidgetsList = next;
        activeWidget = widgetId;
    }

    function toggleWidgetInternal(widgetId) {
        if (!widgetId) {
            closeAllWidgets();
            return ;
        }
        if (isStandaloneWindow(widgetId))
            return ;

        if (isWidgetOpen(widgetId))
            closeWidget(widgetId);
        else
            openWidgetInternal(widgetId);
    }

    onActiveWidgetChanged: {
        if (activeWidget === "") {
            let next = [];
            for (let i = 0; i < activeWidgetsList.length; i++) {
                let item = activeWidgetsList[i];
                if (isFocusWidget(item))
                    next.push(item);

            }
            if (next.length !== activeWidgetsList.length)
                activeWidgetsList = next;

        } else {
            if (activeWidgetsList.indexOf(activeWidget) === -1)
                openWidgetInternal(activeWidget);

        }
    }
    onToggleWidget: (widgetId) => {
        toggleWidgetInternal(widgetId);
    }
    onOpenWidget: (widgetId) => {
        openWidgetInternal(widgetId);
    }
}
