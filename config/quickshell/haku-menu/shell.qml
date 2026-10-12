import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root
    property var request: ({rows: [], customKeys: [], title: "Haku", font: "monospace", accent: "#8d7c74"})
    property var matches: []
    property bool finishing: false
    function filter(query) {
        const terms = query.toLocaleLowerCase().split(/\s+/).filter(t => t.length)
        matches = request.rows.filter(row => terms.every(t => row.label.toLocaleLowerCase().includes(t)))
        list.currentIndex = matches.length ? 0 : -1
    }
    function finish(code, custom) {
        if (finishing) return
        const item = !custom && list.currentIndex >= 0 ? matches[list.currentIndex] : null
        if (code !== 1 && code !== 20 && !item && !request.allowCustom) return
        finishing = true
        result.setText(JSON.stringify({code: code, text: item ? item.label : search.text,
                                      index: item ? item.index : -1}))
    }
    function keyMatches(spec, event) {
        if (!spec) return false
        const parts = spec.toLowerCase().split('+')
        const key = parts.pop()
        const keys = {delete: Qt.Key_Delete, right: Qt.Key_Right, left: Qt.Key_Left}
        return keys[key] === event.key
            && parts.includes('alt') === !!(event.modifiers & Qt.AltModifier)
            && parts.includes('ctrl') === !!(event.modifiers & Qt.ControlModifier)
            && parts.includes('shift') === !!(event.modifiers & Qt.ShiftModifier)
    }
    FileView {
        path: Quickshell.env("HAKU_MENU_REQUEST")
        onLoaded: {
            root.request = JSON.parse(text())
            root.filter("")
            list.currentIndex = Math.min(root.request.selected || 0, root.matches.length - 1)
            search.forceActiveFocus()
        }
    }
    FileView {
        id: result
        path: Quickshell.env("HAKU_MENU_RESULT")
        onSaved: Qt.quit()
    }
    PanelWindow {
        id: window
        screen: Quickshell.screens.find(s => s.name === Quickshell.env("HAKU_MENU_OUTPUT")) || Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "haku-qml-menu"
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: root.finish(1, true) }
        Rectangle {
            id: panel
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Math.min(90, parent.height * 0.1) }
            width: Math.min(700, parent.width - 40)
            height: Math.min(parent.height - 140, column.height + 32)
            radius: 22
            color: "#08090b"
            border.width: 1
            border.color: root.request.accent
            opacity: 0
            y: 72
            Component.onCompleted: entrance.start()
            NumberAnimation { id: entrance; target: panel; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            MouseArea { anchors.fill: parent }
            Column {
                id: column
                x: 16; y: 16; width: parent.width - 32; spacing: 10
                Text {
                    width: parent.width
                    text: root.request.title + (root.request.modes && root.request.modes.length > 1 ? "  · Tab: siguiente" : "")
                    color: root.request.accent
                    font { family: root.request.font; pixelSize: 16; bold: true }
                    elide: Text.ElideRight
                }
                Text {
                    visible: text.length > 0
                    width: parent.width
                    text: root.request.message || ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: "#c4c4c9"
                    font { family: root.request.font; pixelSize: 12 }
                }
                Rectangle {
                    width: parent.width; height: 42; radius: 10; color: "#16171b"
                    TextInput {
                        id: search
                        anchors { fill: parent; margins: 10 }
                        color: "#f2f2f5"
                        selectionColor: root.request.accent
                        selectedTextColor: "#08090b"
                        font { family: root.request.font; pixelSize: 14 }
                        clip: true; focus: true
                        onTextChanged: root.filter(text)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) root.finish(1, true)
                            else if (event.key === Qt.Key_Down) list.currentIndex = Math.min(list.currentIndex + 1, root.matches.length - 1)
                            else if (event.key === Qt.Key_Up) list.currentIndex = Math.max(list.currentIndex - 1, 0)
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.finish(0, !!(event.modifiers & Qt.ControlModifier))
                            else if (event.key === Qt.Key_Tab && root.request.modes && root.request.modes.length > 1) root.finish(20, true)
                            else {
                                for (let i = 0; i < (root.request.customKeys || []).length; i++) {
                                    if (root.keyMatches(root.request.customKeys[i], event)) {
                                        root.finish(10 + i, false)
                                        event.accepted = true
                                        return
                                    }
                                }
                                return
                            }
                            event.accepted = true
                        }
                    }
                }
                ListView {
                    id: list
                    width: parent.width
                    height: Math.min(420, Math.max(1, count) * 48, window.height - 280)
                    clip: true
                    model: root.matches
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width; height: 44; radius: 8
                        color: ListView.isCurrentItem ? Qt.alpha(root.request.accent, 0.22) : "transparent"
                        Image {
                            id: icon
                            x: 8; anchors.verticalCenter: parent.verticalCenter
                            width: visible ? 40 : 0; height: 36
                            visible: row.modelData.icon.length > 0
                            source: !visible ? "" : row.modelData.icon.startsWith('/') ? "file://" + row.modelData.icon : Quickshell.iconPath(row.modelData.icon)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: icon.visible ? 58 : 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: row.modelData.label
                            textFormat: Text.PlainText
                            color: row.ListView.isCurrentItem ? "#ffffff" : "#d4d4db"
                            font { family: root.request.font; pixelSize: 14 }
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { list.currentIndex = row.index; root.finish(0, false) }
                        }
                    }
                }
                Text {
                    text: root.matches.length ? "↑ ↓ · Enter · Esc" : "Sin resultados · Ctrl+Enter: usar texto"
                    color: "#a6a6af"
                    font { family: root.request.font; pixelSize: 11 }
                }
            }
        }
    }
}
