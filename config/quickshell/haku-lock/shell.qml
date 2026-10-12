import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io

ShellRoot {
    id: root
    // Preview never acquires a session lock or sends credentials to PAM.
    readonly property bool preview: Quickshell.env("HAKU_LOCK_PREVIEW") === "1"
    property bool loginVisible: false
    property string status: ""
    property int failures: 0
    property int cooldown: 0
    property color accent: "#8d7c74"
    property string wallpaper: ""
    property string time: Qt.formatDateTime(new Date(), "HHmm")
    property string date: Qt.formatDateTime(new Date(), "dddd, d MMMM")

    // Read-only IPC: neither callers nor the bar can release this lock.
    IpcHandler {
        target: "haku-lock"
        function status(): string { return session.secure ? "secure" : "pending" }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/haku_theme/current_wallpaper"
        onLoaded: root.wallpaper = text().trim()
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/haku_theme/colors.css"
        onLoaded: {
            const match = text().match(/accent_color\s+(#[0-9a-fA-F]{6})/)
            if (match) root.accent = match[1]
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root.time = Qt.formatDateTime(new Date(), "HHmm")
            root.date = Qt.formatDateTime(new Date(), "dddd, d MMMM")
            if (root.cooldown > 0) {
                root.cooldown--
                if (root.cooldown === 0 && root.loginVisible && !root.preview)
                    pam.start()
            }
        }
    }
    function submit(value) {
        if (preview) { status = "Vista previa · no se autentica"; return }
        if (cooldown > 0) return
        if (pam.responseRequired) { pam.respond(value); return }
        if (pam.active) return
        // Start the conversation first. The user submits only when PAM asks.
        status = ""
        pam.start()
    }
    PamContext {
        id: pam
        config: "hyprlock"
        onPamMessage: {
            if (messageIsError) root.status = message
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                session.locked = false
                Qt.quit()
            } else {
                root.failures++
                root.status = "No se pudo autenticar"
                if (root.failures >= 10) {
                    root.cooldown = 60
                    root.failures = 0
                } else if (result === PamResult.Failed || result === PamResult.MaxTries) {
                    Qt.callLater(() => pam.start())
                }
            }
        }
        onError: root.status = "Error de autenticación; vuelve a intentarlo"
    }
    Connections {
        target: root
        function onLoginVisibleChanged() {
            if (root.loginVisible && !root.preview && !pam.active && root.cooldown === 0)
                pam.start()
        }
    }
    WlSessionLock {
        id: session
        locked: !root.preview
        WlSessionLockSurface {
            LockView { anchors.fill: parent; controller: root; auth: pam }
        }
    }
    Variants {
        model: root.preview ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            LockView { anchors.fill: parent; controller: root; auth: pam }
        }
    }
}
