import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Services

PanelWindow {
    id: root
    property bool requested: false
    property real revealProgress: requested ? 1 : 0
    visible: requested || revealProgress > 0
    mask: Region { width: root.requested ? root.width : 0; height: root.requested ? root.height : 0 }
    Behavior on revealProgress {
        enabled: HyprlandService.enableAnimations
        NumberAnimation {
            duration: Math.round((root.requested ? 130 : 80) * Constants.durationFactor)
            easing.type: Easing.OutCubic
        }
    }
    onRevealProgressChanged: {
        if (!requested && revealProgress === 0) windows = [];
    }
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "haku-window-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: requested ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    property var recent: []
    property var windows: []
    property int selected: 0

    function step(delta) {
        const live = ToplevelManager.toplevels.values;
        if (!requested) {
            const active = ToplevelManager.activeToplevel;
            const ordered = (active ? [active] : []).concat(recent, live);
            windows = ordered.filter((item, index) => item && live.indexOf(item) !== -1 && ordered.indexOf(item) === index);
            if (!windows.length) return;
            selected = delta > 0 ? (windows.length > 1 ? 1 : 0) : windows.length - 1;
            requested = true;
            Qt.callLater(() => keyboard.forceActiveFocus());
        } else {
            selected = (selected + delta + windows.length) % windows.length;
        }
        list.positionViewAtIndex(selected, ListView.Contain);
    }
    function acceptSelection() {
        const item = windows[selected];
        requested = false;
        if (item && ToplevelManager.toplevels.values.indexOf(item) !== -1) item.activate();
    }
    function cancel() { requested = false; }
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            const active = ToplevelManager.activeToplevel;
            if (!active) return;
            const live = ToplevelManager.toplevels.values;
            root.recent = [active].concat(root.recent.filter(item => item !== active && live.indexOf(item) !== -1));
        }
    }
    IpcHandler {
        target: "haku-switcher"
        function next() { root.step(1); }
        function previous() { root.step(-1); }
        function close() { root.cancel(); }
        function status(): string {
            return JSON.stringify({visible: root.visible, requested: root.requested, progress: root.revealProgress, count: root.windows.length, selected: root.selected});
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.cancel() }
    FocusScope {
        id: keyboard
        anchors.fill: parent
        focus: root.requested
        enabled: root.requested
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                root.step(event.modifiers & Qt.ShiftModifier ? -1 : 1);
            } else if (event.key === Qt.Key_Down) root.step(1);
            else if (event.key === Qt.Key_Up) root.step(-1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.acceptSelection();
            else if (event.key === Qt.Key_Escape) root.cancel();
            else return;
            event.accepted = true;
        }
        Keys.onReleased: event => {
            if ((event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) && !event.isAutoRepeat) {
                root.acceptSelection();
                event.accepted = true;
            }
        }
        Rectangle {
            opacity: root.revealProgress
            transform: Translate { y: 6 * (1 - root.revealProgress) }
            anchors.centerIn: parent
            width: Math.min(620, parent.width - 40)
            height: Math.min(440, list.contentHeight + 24)
            radius: Constants.sizeLg
            color: Theme.bg
            border.width: 1
            border.color: Theme.bgAccent
            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                spacing: 4
                model: root.windows
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 54
                    radius: Constants.sizeSm
                    color: index === root.selected ? Theme.bgAccent : "transparent"
                    Behavior on color {
                        enabled: HyprlandService.enableAnimations
                        ColorAnimation { duration: Math.round(90 * Constants.durationFactor) }
                    }
                    Column {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                        spacing: 3
                        Text {
                            width: parent.width
                            text: modelData ? modelData.title || modelData.appId : "Ventana cerrada"
                            font { family: Constants.fontFamily; pixelSize: 13; bold: true }
                            color: index === root.selected ? Theme.accent : Theme.fg
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: modelData ? modelData.appId : ""
                            font { family: Constants.fontFamily; pixelSize: 11 }
                            color: Theme.muted
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selected = index
                        onClicked: { root.selected = index; root.acceptSelection(); }
                    }
                }
            }
        }
    }
}
