import QtQuick
import Quickshell

ShellRoot {
    Loader {
        source: "file://" + Quickshell.env("HOME") + "/haku_shell/config/quickshell/minflair-niri/Modules/Clipboard/Clipboard.qml"
        onLoaded: item.closeRequested.connect(Qt.quit)
    }
}
