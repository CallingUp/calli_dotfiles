import QtQuick
import QtTest
import "../../config/quickshell/haku-lock" as Lock

TestCase {
    name: "LockBackground"
    visible: true
    QtObject {
        id: controller
        property string wallpaper: ""
        property bool loginVisible: false
        property bool preview: true
        property int cooldown: 0
        property string time: "1234"
        property string date: "Test"
        property string status: ""
        property color accent: "#B99573"
        property color activeColor: "#D7B894"
        property color errorColor: "#BF616A"
        function submit(value) {}
    }
    QtObject {
        id: auth
        property bool responseRequired: false
        property bool active: false
        signal completed()
    }
    Lock.LockView { id: view; width: 800; height: 600; controller: controller; auth: auth }
    function test_missingWallpaperIsOpaqueBlack() {
        const background = findChild(view, "lockFallbackBackground")
        verify(background !== null)
        compare(background.color, Qt.rgba(0, 0, 0, 1))
        compare(background.width, view.width)
        compare(background.height, view.height)
        compare(background.visible, true)
    }
}
