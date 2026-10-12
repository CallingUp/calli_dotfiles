import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core.Services as NiriBackend
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils

Item {
    id: root

    property color bgColor: Theme.bgSecondary
    property bool compact: false
    property int customHeight: compact ? 20 : SettingsService.barWidgetHeight
    readonly property real containerPadding: compact ? 8 : 10
    readonly property int dotHeight: compact ? 6 : 8
    readonly property int activePillWidth: compact ? 18 : 24
    readonly property int activeWsId: NiriBackend.HyprlandService.focusedWorkspace ? NiriBackend.HyprlandService.focusedWorkspace.id : 1
    // Niri can retain named empty workspaces: show occupied ones + one spare.
    readonly property var workspaceSlots: {
        const all = NiriBackend.HyprlandService.workspaces.values;
        const occupied = all.filter(ws => ws.toplevels && ws.toplevels.values.length > 0);
        const spare = all.find(ws => ws.id === activeWsId && !occupied.some(o => o.id === ws.id))
            || all.find(ws => !occupied.some(o => o.id === ws.id));
        const slots = occupied.slice();
        slots.push(spare || {id: Math.max(0, ...occupied.map(ws => ws.id)) + 1});
        return slots.sort((a, b) => a.id - b.id);
    }
    readonly property int visibleWorkspaceCount: workspaceSlots.length

    function handleWheel(wheel) {
        const current = workspaceSlots.findIndex(ws => ws.id === activeWsId);
        const next = current + (wheel.angleDelta.y > 0 ? -1 : 1);
        if (next >= 0 && next < workspaceSlots.length)
            NiriBackend.HyprlandService.focusWorkspace(workspaceSlots[next].id);
    }

    implicitHeight: customHeight
    height: customHeight
    Layout.preferredHeight: customHeight
    Layout.preferredWidth: implicitWidth
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: Math.round(hLayout.implicitWidth + (root.bgColor === "transparent" ? 0 : (containerPadding * 2)))
    width: implicitWidth

    Rectangle {
        id: bgContainer

        anchors.fill: parent
        color: root.bgColor
        radius: DisplayProfileService.gameModeActive ? 0 : height / 2
        visible: root.bgColor !== "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Constants.animFast
            }

        }

    }

    MouseArea {
        id: wheelArea

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            return root.handleWheel(wheel);
        }
    }

    Row {
        id: hLayout

        anchors.centerIn: parent
        spacing: root.compact ? 5 : 6

        Repeater {
            model: root.visibleWorkspaceCount

            Item {
                id: wsSlot

                readonly property int wsId: root.workspaceSlots[index].id
                readonly property bool isVisibleSlot: true
                readonly property var workspace: NiriBackend.HyprlandService.workspaces.values.find((ws) => {
                    return ws.id === wsId;
                })
                readonly property bool isActive: root.activeWsId === wsId
                readonly property bool hasActualWindows: {
                    if (workspace && workspace.toplevels && workspace.toplevels.values) {
                        if (workspace.toplevels.values.length > 0)
                            return true;

                    }
                    if (NiriBackend.HyprlandService.toplevels && NiriBackend.HyprlandService.toplevels.values)
                        return NiriBackend.HyprlandService.toplevels.values.some((top) => {
                        return top && top.workspace && top.workspace.id === wsId;
                    });

                    return false;
                }
                readonly property bool hasWindows: hasActualWindows
                readonly property bool isHovered: mouseAreaH.containsMouse

                visible: opacity > 0.001
                opacity: isVisibleSlot ? 1 : 0
                height: root.dotHeight
                width: isActive ? root.activePillWidth : root.dotHeight

                Rectangle {
                    id: dotItem

                    anchors.centerIn: parent
                    height: root.dotHeight
                    width: parent.width
                    radius: DisplayProfileService.gameModeActive ? 0 : height / 2
                    color: {
                        if (wsSlot.isActive)
                            return Theme.accent;

                        if (wsSlot.hasWindows)
                            return wsSlot.isHovered ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.95) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65);

                        return wsSlot.isHovered ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22);
                    }
                    scale: mouseAreaH.pressed ? 0.85 : (wsSlot.isHovered && !wsSlot.isActive ? 1.2 : 1)

                    Behavior on color {
                        ColorAnimation {
                            duration: Constants.animFast
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutQuad
                        }

                    }

                }

                MouseArea {
                    id: mouseAreaH

                    anchors.centerIn: parent
                    width: Math.max(parent.width, 14)
                    height: Math.max(parent.height, 18)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NiriBackend.HyprlandService.dispatch('hl.dsp.focus({workspace=' + wsSlot.wsId + '})')
                    onWheel: (wheel) => {
                        return root.handleWheel(wheel);
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Constants.animFast
                    }

                }

            }

        }

    }

    Connections {
        function onRawEvent(event) {
            if (!event || !event.name)
                return ;

            const ev = event.name;
            if (ev === "openwindow" || ev === "closewindow" || ev === "movewindowv2" || ev === "createworkspacev2" || ev === "destroyworkspacev2")
                refreshDebounce.restart();

        }

        target: NiriBackend.HyprlandService
    }

    Timer {
        id: refreshDebounce

        interval: 100
        repeat: false
        onTriggered: NiriBackend.HyprlandService.refreshWorkspaces()
    }

}
