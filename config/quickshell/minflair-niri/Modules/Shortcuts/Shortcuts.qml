import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: root
    signal closeRequested()
    property var rows: []
    property var matches: []
    property string error: ""
    function filter() {
        const terms = search.text.toLocaleLowerCase().split(/\s+/).filter(t => t.length)
        matches = rows.filter(r => terms.every(t => (r.key + " " + r.label + " " + r.action + " " + r.category).toLocaleLowerCase().includes(t)))
    }
    IpcHandler { target: "haku-shortcuts"; function close() { root.closeRequested() } }
    Process {
        command: ["bash", Quickshell.env("HOME") + "/haku_shell/scripts/bin/haku-info-worker", "shortcuts"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { const data = JSON.parse(text); root.rows = data.rows; root.error = data.error; root.filter() }
                catch (e) { root.error = "No se pudieron leer los atajos: " + e }
            }
        }
    }
    PanelWindow {
        id: window
        visible: true
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "haku-shortcuts"
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(980, window.width - 40)
            height: Math.min(700, window.height - 80)
            radius: 22
            color: "#000000"
            border.color: "#705542"
            border.width: 1
            opacity: 0
            Component.onCompleted: entrance.start()
            NumberAnimation { id: entrance; target: panel; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
            MouseArea { anchors.fill: parent }
            Text {
                x: 24; y: 20; text: "Atajos de teclado"
                color: "#D7B894"; font { family: "CommitMono Nerd Font"; pixelSize: 20; bold: true }
            }
            Text {
                x: 24; y: 51; text: "Niri · configuración actual · Mod = Super / tecla Windows"
                color: "#C5AF98"; font { family: "CommitMono Nerd Font"; pixelSize: 12 }
            }
            Rectangle {
                x: 24; y: 80; width: parent.width - 48; height: 42; radius: 10; color: "#211813"
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    visible: !search.text.length; text: "Buscar acción, tecla o sección…"; color: "#A28B77"
                    font { family: "CommitMono Nerd Font"; pixelSize: 13 }
                }
                TextInput {
                    id: search
                    anchors { fill: parent; margins: 12 }
                    color: "#E8DCC8"; selectionColor: "#B99573"; clip: true; focus: true
                    font { family: "CommitMono Nerd Font"; pixelSize: 13 }
                    Component.onCompleted: Qt.callLater(() => forceActiveFocus())
                    onTextChanged: root.filter()
                    Keys.onEscapePressed: root.closeRequested()
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                }
            }
            ListView {
                id: list
                x: 24; y: 138; width: parent.width - 48; height: parent.height - 184
                clip: true; spacing: 4; model: root.matches
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                section.property: "category"
                section.delegate: Text {
                    required property string section
                    width: list.width; height: 34; text: section; color: "#B99573"
                    verticalAlignment: Text.AlignVCenter
                    font { family: "CommitMono Nerd Font"; pixelSize: 13; bold: true }
                }
                delegate: Rectangle {
                    required property var modelData
                    width: list.width; height: Math.max(48, description.implicitHeight + 20); radius: 8
                    color: ListView.isCurrentItem ? "#211813" : "#100D0B"
                    Text {
                        x: 12; y: 14; width: Math.min(280, list.width * 0.38)
                        text: modelData.key; wrapMode: Text.Wrap; color: "#D7B894"
                        font { family: "CommitMono Nerd Font"; pixelSize: 12; bold: true }
                    }
                    Text {
                        id: description
                        x: Math.min(280, list.width * 0.38) + 24; y: 10; width: parent.width - x - 12
                        text: modelData.label; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
                        color: "#E8DCC8"; font { family: "CommitMono Nerd Font"; pixelSize: 12 }
                    }
                }
            }
            Text {
                x: 24; anchors { bottom: parent.bottom; bottomMargin: 15 }
                text: root.error || (root.matches.length + " atajos · ↑ ↓ navegar · Esc / clic fuera: cerrar")
                color: "#A28B77"; font { family: "CommitMono Nerd Font"; pixelSize: 11 }
            }
        }
    }
}
