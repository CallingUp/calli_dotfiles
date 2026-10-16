import Quickshell
import QtQuick

ShellRoot {
    Loader {
        source: "file://" + Quickshell.env("HOME") + "/haku_shell/config/quickshell/minflair-niri/Modules/WallpaperCarousel/Carousel.qml"
        onLoaded: item.closeRequested.connect(Qt.quit)
    }
}
