import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property var settings: ({accent: "#8d7c74", font: "monospace", rows: [], cacheDir: ""})
    property var rows: []
    property var filtered: []
    property string category: "all"
    property string previewText: ""
    property string previewImage: ""
    property string previewMeta: ""
    property string error: ""
    property bool confirmWipe: false
    property string pendingId: ""
    property string action: ""
    readonly property var selected: list.currentIndex >= 0 ? (filtered[list.currentIndex] || null) : null
    readonly property string backend: Quickshell.env("HOME") + "/haku_shell/scripts/bin/haku-clipboard"
    function filter() {
        const words = search.text.toLocaleLowerCase().split(/\s+/).filter(s => s.length)
        filtered = rows.filter(r => (category === "all" || r.kind === category) && words.every(w => r.label.toLocaleLowerCase().includes(w)))
        list.currentIndex = filtered.length ? 0 : -1
        previewTimer.restart()
    }
    function operate(name) {
        if (actionProcess.running || (name !== "wipe" && !selected)) return
        action = name
        error = ""
        actionProcess.command = ["python3", backend, name].concat(name === "wipe" ? [] : [selected.id])
        actionProcess.running = true
    }
    function loadPreview() {
        previewText = ""; previewImage = ""; previewMeta = ""
        if (!selected) return
        if (previewProcess.running) { previewTimer.restart(); return }
        pendingId = selected.id
        previewProcess.command = ["python3", backend, "preview", pendingId, settings.cacheDir]
        previewProcess.running = true
    }
    FileView {
        path: Quickshell.env("HAKU_MENU_REQUEST")
        onLoaded: { root.settings = JSON.parse(text()); root.rows = root.settings.rows; root.filter(); search.forceActiveFocus() }
    }
    Timer { id: previewTimer; interval: 100; onTriggered: root.loadPreview() }
    Process {
        id: previewProcess
        stdout: StdioCollector { id: previewOutput }
        onExited: {
            if (!root.selected || root.selected.id !== root.pendingId) { previewTimer.restart(); return }
            try {
                const data = JSON.parse(previewOutput.text)
                root.previewText = data.error || data.text || ""
                root.previewImage = data.image ? "file://" + data.image : ""
                root.previewMeta = (data.bytes !== undefined ? (data.bytes / 1024).toFixed(1) + " KiB" : "") + (data.truncated ? " · vista previa recortada" : "")
            } catch (_) { root.previewText = "Vista previa no disponible" }
        }
    }
    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOutput }
        onExited: {
            try {
                const data = JSON.parse(actionOutput.text)
                if (!data.ok) { root.error = data.error; return }
                if (root.action === "copy") { Qt.quit(); return }
                const previous = list.currentIndex
                root.confirmWipe = false
                root.rows = data.rows
                root.filter()
                list.currentIndex = Math.min(previous, root.filtered.length - 1)
            } catch (_) { root.error = "No se pudo completar la operación" }
        }
    }
    PanelWindow {
        id: window
        screen: Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "haku-clipboard"
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
        Rectangle {
            id: panel
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Math.min(90, parent.height * 0.1) }
            width: Math.min(980, parent.width - 40)
            height: Math.min(620, parent.height - 130)
            radius: 22; color: "#08090b"
            border { width: 1; color: root.settings.accent }
            opacity: 0
            Component.onCompleted: entrance.start()
            NumberAnimation { id: entrance; target: panel; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            MouseArea { anchors.fill: parent }
            Text {
                x: 20; y: 18
                text: "󰅌  Portapapeles"
                color: root.settings.accent
                font { family: root.settings.font; pixelSize: 17; bold: true }
            }
            Text {
                anchors { top: parent.top; topMargin: 22; right: clearButton.left; rightMargin: 16 }
                text: root.filtered.length + " / " + root.rows.length
                color: "#a6a6af"
                font { family: root.settings.font; pixelSize: 12 }
            }
            ActionButton {
                id: clearButton
                anchors { top: parent.top; topMargin: 12; right: parent.right; rightMargin: 16 }
                label: "󰆴  Vaciar"; enabled: root.rows.length > 0 && !actionProcess.running
                onClicked: root.confirmWipe = true
            }
            Rectangle {
                id: searchBox
                x: 16; y: 58; width: parent.width - 32; height: 44; radius: 10; color: "#16171b"
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "󰍉"; color: root.settings.accent
                    font { family: root.settings.font; pixelSize: 18 }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 40; verticalCenter: parent.verticalCenter }
                    visible: !search.text.length
                    text: "Buscar en el historial…"; color: "#9696a1"
                    font { family: root.settings.font; pixelSize: 14 }
                }
                TextInput {
                    id: search
                    anchors { fill: parent; leftMargin: 40; rightMargin: 12; topMargin: 12; bottomMargin: 10 }
                    color: "#f2f2f5"; selectionColor: root.settings.accent; selectedTextColor: "#08090b"
                    font { family: root.settings.font; pixelSize: 14 }
                    focus: true; clip: true
                    onTextChanged: root.filter()
                    Keys.onPressed: event => {
                        if (root.confirmWipe) {
                            if (event.key === Qt.Key_Escape) root.confirmWipe = false
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.operate("wipe")
                            event.accepted = true; return
                        }
                        if (event.key === Qt.Key_Escape) Qt.quit()
                        else if (event.key === Qt.Key_Down) list.currentIndex = Math.min(list.currentIndex + 1, root.filtered.length - 1)
                        else if (event.key === Qt.Key_Up) list.currentIndex = Math.max(list.currentIndex - 1, 0)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.operate("copy")
                        else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.AltModifier)) root.operate("delete")
                        else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier) && !actionProcess.running) {
                            root.action = "refresh"; actionProcess.command = ["python3", root.backend, "list"]; actionProcess.running = true
                        } else return
                        event.accepted = true
                    }
                }
            }
            Row {
                x: 16; y: 112; spacing: 8
                Repeater {
                    model: [{key:"all",name:"Todo"},{key:"text",name:"Texto"},{key:"image",name:"Imágenes"},{key:"link",name:"Enlaces"}]
                    ActionButton {
                        required property var modelData
                        label: modelData.name; active: root.category === modelData.key
                        onClicked: { root.category = modelData.key; root.filter(); search.forceActiveFocus() }
                    }
                }
            }
            ListView {
                id: list
                x: 16; y: 158; width: Math.floor((parent.width - 48) * 0.48); height: parent.height - 210
                model: root.filtered; spacing: 6; clip: true
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: { positionViewAtIndex(currentIndex, ListView.Contain); previewTimer.restart() }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width; height: 64; radius: 10
                    color: ListView.isCurrentItem ? Qt.alpha(root.settings.accent, 0.2) : "#121317"
                    Rectangle { width: 3; height: 26; radius: 2; x: 0; anchors.verticalCenter: parent.verticalCenter; visible: row.ListView.isCurrentItem; color: root.settings.accent }
                    Text {
                        x: 12; y: 9
                        text: ({image:"󰸉  Imagen",link:"󰌷  Enlace",text:"󰈙  Texto",binary:"󰆧  Archivo"})[row.modelData.kind] || "Texto"
                        color: root.settings.accent
                        font { family: root.settings.font; pixelSize: 11; bold: true }
                    }
                    Text {
                        x: 12; y: 31; width: parent.width - 58
                        text: row.modelData.label; textFormat: Text.PlainText; elide: Text.ElideRight
                        color: "#e2e2e8"
                        font { family: root.settings.font; pixelSize: 13 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { list.currentIndex = row.index; search.forceActiveFocus() }
                        onDoubleClicked: root.operate("copy")
                    }
                    ActionButton {
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        label: "×"; width: 30; enabled: !actionProcess.running
                        onClicked: { list.currentIndex = row.index; root.operate("delete") }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.filtered.length === 0
                    text: root.rows.length ? "Sin coincidencias" : "El historial está vacío"
                    color: "#a6a6af"
                    font { family: root.settings.font; pixelSize: 13 }
                }
            }
            Rectangle {
                id: previewPanel
                x: list.x + list.width + 12; y: list.y
                width: parent.width - x - 16; height: list.height; radius: 12; color: "#121317"
                Text {
                    x: 14; y: 12
                    text: "Vista previa"; color: root.settings.accent
                    font { family: root.settings.font; pixelSize: 12; bold: true }
                }
                Controls.ScrollView {
                    x: 14; y: 38; width: parent.width - 28; height: parent.height - 94
                    visible: !root.previewImage
                    clip: true
                    Text {
                        width: previewPanel.width - 28
                        text: root.previewText || (root.selected ? "Cargando…" : "Selecciona una entrada")
                        textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
                        color: "#dedee6"
                        font { family: root.settings.font; pixelSize: 13 }
                    }
                }
                Image {
                    x: 14; y: 38; width: parent.width - 28; height: parent.height - 94
                    visible: root.previewImage.length > 0
                    source: root.previewImage
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 800; sourceSize.height: 800; asynchronous: true
                }
                Text {
                    x: 14; anchors { bottom: parent.bottom; bottomMargin: 21 }
                    width: parent.width - copyButton.width - 40
                    text: root.previewMeta; elide: Text.ElideRight; color: "#9696a1"
                    font { family: root.settings.font; pixelSize: 11 }
                }
                ActionButton {
                    id: copyButton
                    anchors { bottom: parent.bottom; bottomMargin: 10; right: parent.right; rightMargin: 12 }
                    label: "󰆏  Copiar"; active: true; enabled: root.selected !== null && !actionProcess.running
                    onClicked: root.operate("copy")
                }
            }
            Text {
                x: 20; anchors { bottom: parent.bottom; bottomMargin: 16 }
                width: parent.width - 40
                text: root.error || "↑ ↓ seleccionar · Enter copiar · Alt+Supr borrar · Ctrl+R actualizar · Esc cerrar"
                color: root.error ? "#f09b9b" : "#9696a1"
                font { family: root.settings.font; pixelSize: 11 }
                elide: Text.ElideRight
            }
            Rectangle {
                anchors.fill: parent; radius: parent.radius; color: "#ef08090b"; visible: root.confirmWipe
                MouseArea { anchors.fill: parent }
                Column {
                    anchors.centerIn: parent; spacing: 18
                    Text { text: "¿Vaciar todo el historial?"; color: root.settings.accent; font { family: root.settings.font; pixelSize: 17; bold: true } }
                    Text { text: "Esta acción no se puede deshacer."; color: "#dedee6"; font { family: root.settings.font; pixelSize: 13 } }
                    Row {
                        spacing: 12
                        ActionButton { label: "Cancelar"; onClicked: { root.confirmWipe = false; search.forceActiveFocus() } }
                        ActionButton { label: "Vaciar"; active: true; enabled: !actionProcess.running; onClicked: root.operate("wipe") }
                    }
                }
            }
        }
    }
}
