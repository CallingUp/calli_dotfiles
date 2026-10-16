import QtQuick

Item {
    id: view
    required property var controller
    required property var auth
    focus: true
    // Opaque fallback during asynchronous image loading or a missing wallpaper.
    Rectangle {
        objectName: "lockFallbackBackground"
        anchors.fill: parent
        color: "#000000"
    }
    Image {
        anchors.fill: parent
        source: view.controller.wallpaper ? "file://" + view.controller.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle { anchors.fill: parent; color: "#48000000" }
    Column {
        anchors.centerIn: parent
        spacing: 12
        opacity: view.controller.loginVisible ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.controller.time.slice(0, 2)
            font { family: "Maple Mono NF"; pixelSize: 180; bold: true }
            color: view.controller.accent
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.controller.time.slice(2)
            font { family: "Maple Mono NF"; pixelSize: 180; bold: true }
            color: view.controller.activeColor
        }
    }
    Text {
        anchors { bottom: parent.bottom; bottomMargin: 42; horizontalCenter: parent.horizontalCenter }
        text: view.controller.preview ? "Vista previa · Esc para salir" : view.controller.date
        color: view.controller.accent
        font { family: "Maple Mono NF"; pixelSize: 16 }
    }
    TextInput {
        id: input
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 960)
        visible: view.controller.loginVisible
        enabled: view.controller.cooldown === 0 && (view.controller.preview || auth.responseRequired || !auth.active)
        echoMode: TextInput.Password
        passwordCharacter: "*"
        horizontalAlignment: TextInput.AlignHCenter
        color: view.controller.accent
        selectionColor: Qt.darker(view.controller.accent, 1.5)
        font { family: "Maple Mono NF"; pixelSize: 40; bold: true }
        maximumLength: 4096
        clip: true
        onAccepted: {
            const response = text
            clear()
            view.controller.submit(response)
        }
        Keys.onEscapePressed: {
            clear()
            if (view.controller.preview) Qt.quit()
        }
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: input.bottom; topMargin: 24 }
        text: view.controller.cooldown > 0 ? "Espera " + view.controller.cooldown + " s" : view.controller.status
        color: view.controller.errorColor
        font { family: "Maple Mono NF"; pixelSize: 16 }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && view.controller.preview) { Qt.quit(); return }
        if (!view.controller.loginVisible) {
            view.controller.loginVisible = true
            input.forceActiveFocus()
            event.accepted = true
        }
    }
    Connections {
        target: view.auth
        function onCompleted() { input.clear(); input.forceActiveFocus() }
        function onResponseRequiredChanged() {
            if (view.auth.responseRequired) input.forceActiveFocus()
        }
    }
}
