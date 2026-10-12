import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    IpcHandler {
        target: "haku-wallpaper"
        function close() { Qt.quit() }
    }
    property var settings: ({accent:"#8d7c74", font:"monospace", rows:[], current:""})
    property color accent: settings.accent
    property var localRows: []
    property var webRows: []
    property var items: []
    property string source: "local"
    property string current: ""
    property int targetIndex: 0
    property real position: 0
    property var thumbnails: ({})
    property var thumbnailQueue: []
    property var thumbnailRequest: null
    property string status: ""
    property bool webDirty: false
    property string webQuery: ""
    property int webPage: 0
    property int lastPage: 1
    property int total: 0
    property string pendingQuery: ""
    property int pendingPage: 1
    property string action: ""
    property var actionItem: null
    property var trashItem: null
    property bool ready: false
    property bool revealed: false
    property real revealProgress: revealed ? 1 : 0
    Behavior on revealProgress {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    property real wheelRemainder: 0
    readonly property string backend: Quickshell.env("HOME") + "/haku_shell/scripts/bin/haku-wallpaper-selector"
    readonly property var selected: items.length ? items[mod(targetIndex, items.length)] : null
    function mod(value, length) { return ((value % length) + length) % length }
    function updateLocal() {
        const words = search.text.toLocaleLowerCase().split(/\s+/).filter(s => s.length)
        items = localRows.filter(row => words.every(w => row.label.toLocaleLowerCase().includes(w)))
        resetPosition(items.findIndex(r => r.path === current))
    }
    function resetPosition(index) {
        ready = false
        targetIndex = Math.max(0, index)
        position = targetIndex
        ready = true
        prepareThumbnails()
    }
    function navigate(delta) {
        if (!items.length || trashItem || actionProcess.running) return
        // Retarget immediately; no queued rotations or repeat timer.
        targetIndex += delta
        position = targetIndex
        prepareThumbnails()
        if (source === "web" && mod(targetIndex, items.length) >= items.length - 3 && webPage < lastPage)
            fetchWeb(webQuery, webPage + 1)
    }
    function prepareThumbnails() {
        const queue = []
        for (const offset of [0,-1,1,-2,2,-3,3]) {
            if (!items.length) break
            const item = items[mod(targetIndex + offset, items.length)]
            if (!thumbnails[item.key] && !queue.some(r => r.key === item.key) && (!thumbnailRequest || item.key !== thumbnailRequest.key)) queue.push(item)
        }
        thumbnailQueue = queue
        pumpThumbnail()
    }
    function pumpThumbnail() {
        if (thumbProcess.running || !thumbnailQueue.length) return
        thumbnailRequest = thumbnailQueue[0]
        thumbnailQueue = thumbnailQueue.slice(1)
        thumbProcess.running = true
    }
    function toggleSource() {
        if (actionProcess.running) return
        source = source === "local" ? "web" : "local"
        search.text = ""
        status = ""
        if (source === "local") updateLocal()
        else {
            items = webRows
            resetPosition(0)
            webDirty = false
            if (!webRows.length) fetchWeb("", 1)
        }
        search.forceActiveFocus()
    }
    function fetchWeb(query, page) {
        if (webProcess.running) return
        pendingQuery = query; pendingPage = page
        status = "Wallhaven · buscando…"
        webProcess.running = true
    }
    function accept() {
        if (trashItem) { perform("trash", trashItem); return }
        if (source === "web" && (webDirty || !items.length)) {
            fetchWeb(search.text.trim(), 1); return
        }
        if (selected) perform("apply", selected)
    }
    function perform(name, item) {
        if (actionProcess.running) return
        action = name; actionItem = item
        status = name === "apply" ? (item.kind === "web" ? "Descargando y aplicando…" : "Aplicando…") : "Enviando a la Papelera…"
        actionProcess.running = true
    }
    function requestTrash() {
        if (!selected || actionProcess.running) return
        if (source === "web") {
            webRows = webRows.filter(r => r.key !== selected.key)
            items = webRows; resetPosition(0)
            status = "Resultado ocultado durante esta sesión"
        } else if (selected.path === current) status = "No se puede borrar el fondo activo"
        else trashItem = selected
    }
    Behavior on position { enabled: root.ready; NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
    FileView {
        path: Quickshell.env("HAKU_MENU_REQUEST")
        onLoaded: {
            root.settings = JSON.parse(text()); root.localRows = root.settings.rows
            root.current = root.settings.current; root.updateLocal(); search.forceActiveFocus()
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/haku_theme/colors.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const color = text().match(/accent_color\s+(#[\da-fA-F]{6})/); if (color) root.accent = color[1] }
    }
    Process {
        id: thumbProcess
        command: ["python3", root.backend, "--worker"]
        stdinEnabled: true
        onStarted: write(JSON.stringify({action:"thumb", item:root.thumbnailRequest}) + "\n")
        stdout: StdioCollector { id: thumbOutput }
        onExited: {
            try {
                const result = JSON.parse(thumbOutput.text)
                if (result.ok) root.thumbnails = Object.assign({}, root.thumbnails, {[result.key]: "file://" + result.image})
            } catch (_) {}
            root.thumbnailRequest = null
            Qt.callLater(root.pumpThumbnail)
        }
    }
    Process {
        id: webProcess
        command: ["python3", root.backend, "--worker"]
        stdinEnabled: true
        onStarted: write(JSON.stringify({action:"search", query:root.pendingQuery, page:root.pendingPage}) + "\n")
        stdout: StdioCollector { id: webOutput }
        onExited: {
            try {
                const result = JSON.parse(webOutput.text)
                if (!result.ok) { root.status = result.error; return }
                root.webQuery = result.query; root.webPage = result.page; root.lastPage = result.lastPage; root.total = result.total
                root.webRows = result.page === 1 ? result.rows : root.webRows.concat(result.rows.filter(r => !root.webRows.some(old => old.key === r.key)))
                if (root.source === "web") {
                    root.items = root.webRows
                    if (result.page === 1) root.resetPosition(0)
                    else root.prepareThumbnails()
                    root.webDirty = false
                }
                root.status = result.total ? "Favoritos · SFW · 1920×1080 · 16:9" : "Sin resultados"
            } catch (_) { root.status = "No se pudo cargar Wallhaven" }
        }
    }
    Process {
        id: actionProcess
        command: ["python3", root.backend, "--worker"]
        stdinEnabled: true
        onStarted: write(JSON.stringify({action:root.action, item:root.actionItem}) + "\n")
        stdout: StdioCollector { id: actionOutput }
        onExited: {
            root.trashItem = null
            try {
                const result = JSON.parse(actionOutput.text)
                if (!result.ok) { root.status = result.error; return }
                root.current = result.current
                if (root.action === "trash") { root.localRows = result.rows; root.updateLocal(); root.status = "Fondo enviado a la Papelera" }
                else root.status = result.unchanged ? "Este fondo ya está activo" : "󰄬 Fondo aplicado"
            } catch (_) { root.status = "No se pudo completar la operación" }
            search.forceActiveFocus()
        }
    }
    PanelWindow {
        id: window
        screen: Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "haku-wallpaper-carousel"
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
        Item {
            id: panel
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(440, parent.width - 32)
            height: Math.min(920, parent.height - 64)
            // Animate progress, not geometry: width changes during mapping must
            // never start an unintended slide from x=0 towards the left edge.
            x: -width * (1 - root.revealProgress)
            Connections {
                target: panel.Window.window
                enabled: !root.revealed
                function onFrameSwapped() {
                    Qt.callLater(() => { root.revealed = true })
                }
            }
            Rectangle { x: -22; width: parent.width + 22; height: parent.height; radius: 22; color: "#08090b" }
            MouseArea {
                anchors.fill: parent
                onWheel: event => {
                    if (event.angleDelta.y) {
                        root.wheelRemainder += event.angleDelta.y
                        if (Math.abs(root.wheelRemainder) >= 90) {
                            root.navigate(root.wheelRemainder < 0 ? 1 : -1)
                            root.wheelRemainder = 0
                        }
                    }
                    event.accepted = true
                }
            }
            Text {
                x: 20; y: 18; text: "󰸉  Wallpapers"; color: root.accent
                font { family: root.settings.font; pixelSize: 17; bold: true }
            }
            Row {
                x: 20; y: 52; spacing: 8
                SourceButton { label: "Local"; active: root.source === "local"; onClicked: if (root.source !== "local") root.toggleSource() }
                SourceButton { label: "Wallhaven"; active: root.source === "web"; onClicked: if (root.source !== "web") root.toggleSource() }
            }
            Rectangle {
                x: 20; y: 98; width: parent.width - 40; height: 42; radius: 10; color: "#17181c"
                Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; color: root.accent; font { family: root.settings.font; pixelSize: 17 } }
                Text {
                    x: 38; anchors.verticalCenter: parent.verticalCenter; visible: !search.text
                    text: root.source === "local" ? "Filtrar fondos…" : "Buscar en Wallhaven…"
                    color: "#9696a1"; font { family: root.settings.font; pixelSize: 13 }
                }
                TextInput {
                    id: search
                    anchors { fill: parent; leftMargin: 38; rightMargin: 10; topMargin: 11; bottomMargin: 10 }
                    color: "#f0f0f5"; selectionColor: root.accent; selectedTextColor: "#08090b"
                    font { family: root.settings.font; pixelSize: 13 }
                    focus: true; clip: true
                    onTextChanged: {
                        if (root.source === "local") root.updateLocal()
                        else root.webDirty = true
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { if (root.trashItem) root.trashItem = null; else Qt.quit() }
                        else if (event.key === Qt.Key_Up) root.navigate(-1)
                        else if (event.key === Qt.Key_Down) root.navigate(1)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.accept()
                        else if (event.key === Qt.Key_Tab) root.toggleSource()
                        else if (event.key === Qt.Key_Delete && !search.text.length) root.requestTrash()
                        else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) { search.selectAll(); root.webDirty = true }
                        else return
                        event.accepted = true
                    }
                }
            }
            Item {
                id: viewport
                x: 0; y: 152; width: parent.width; height: parent.height - 246
                clip: true
                Repeater {
                    model: 7
                    Rectangle {
                        id: card
                        required property int index
                        readonly property int center: Math.round(root.position)
                        readonly property int logicalIndex: center + root.mod(index - root.mod(center, 7) + 3, 7) - 3
                        readonly property real delta: logicalIndex - root.position
                        readonly property var entry: root.items.length ? root.items[root.mod(logicalIndex, root.items.length)] : null
                        width: Math.min(350, viewport.width - 80); height: 242
                        x: 24 + Math.max(0, 38 - 22 * delta * delta)
                        y: viewport.height / 2 + delta * 220 - height / 2
                        scale: Math.max(0.65, 1 - Math.abs(delta) * 0.15)
                        opacity: Math.max(0, 1 - Math.abs(delta) * 0.32)
                        z: 10 - Math.abs(delta)
                        visible: entry !== null && Math.abs(delta) < 3.2 && (root.items.length > 1 || logicalIndex === root.targetIndex)
                        radius: 14; color: Math.abs(delta) < 0.5 ? "#24252b" : "#131418"
                        border { width: Math.abs(delta) < 0.5 ? 2 : 0; color: root.accent }
                        Item {
                            x: 7; y: 7; width: parent.width - 14; height: 198; clip: true
                            Image {
                                anchors.fill: parent
                                source: card.entry ? root.thumbnails[card.entry.key] || "" : ""
                                fillMode: Image.PreserveAspectCrop; asynchronous: true
                                sourceSize.width: 420; sourceSize.height: 300
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: card.entry !== null && !root.thumbnails[card.entry.key]
                                text: "󰸉"; color: root.accent
                                font { family: root.settings.font; pixelSize: 30 }
                            }
                        }
                        Text {
                            x: 12; anchors { bottom: parent.bottom; bottomMargin: 12 }
                            width: parent.width - 24
                            text: card.entry ? ((card.entry.path === root.current ? "󰄬 ACTUAL · " : "") + card.entry.label + (card.entry.resolution ? " · " + card.entry.resolution : "")) : ""
                            textFormat: Text.PlainText; elide: Text.ElideRight
                            color: card.entry && card.entry.path === root.current ? root.accent : "#e0e0e7"
                            font { family: root.settings.font; pixelSize: 12; bold: Math.abs(card.delta) < 0.5 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (Math.abs(card.delta) < 0.5) root.accept()
                                else root.navigate(card.logicalIndex - root.targetIndex)
                                search.forceActiveFocus()
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent; visible: !root.items.length
                    text: webProcess.running ? "Buscando…" : "No se encontraron fondos"
                    color: "#aaaab3"; font { family: root.settings.font; pixelSize: 13 }
                }
            }
            Text {
                anchors { bottom: parent.bottom; bottomMargin: 74; horizontalCenter: parent.horizontalCenter }
                text: root.items.length ? (root.mod(root.targetIndex, root.items.length) + 1) + " / " + (root.source === "web" ? root.total : root.items.length) : ""
                color: root.accent; font { family: root.settings.font; pixelSize: 13; bold: true }
            }
            Text {
                x: 20
                anchors { bottom: parent.bottom; bottomMargin: 44 }
                width: parent.width - 40
                text: root.status || "↑ ↓ / rueda · Enter aplica · Tab cambia origen"
                textFormat: Text.PlainText; elide: Text.ElideRight; color: "#b9b9c3"
                font { family: root.settings.font; pixelSize: 11 }
            }
            Text {
                x: 20
                anchors { bottom: parent.bottom; bottomMargin: 22 }
                width: parent.width - 40
                text: "Supr: Papelera · Ctrl+F: buscar · Esc: cerrar"
                color: "#858590"; font { family: root.settings.font; pixelSize: 11 }
            }
            Rectangle {
                anchors.fill: parent; color: "#f508090b"; radius: 22; visible: root.trashItem !== null
                MouseArea { anchors.fill: parent }
                Column {
                    anchors.centerIn: parent; width: parent.width - 40; spacing: 18
                    Text { width: parent.width; text: "¿Enviar a la Papelera?"; color: root.accent; font { family: root.settings.font; pixelSize: 17; bold: true } }
                    Text { width: parent.width; text: root.trashItem ? root.trashItem.label : ""; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: "#dedee6"; font { family: root.settings.font; pixelSize: 13 } }
                    Row {
                        spacing: 12
                        SourceButton { label: "Cancelar"; onClicked: root.trashItem = null }
                        SourceButton { label: "Papelera"; active: true; onClicked: root.accept() }
                    }
                }
            }
        }
    }
}
