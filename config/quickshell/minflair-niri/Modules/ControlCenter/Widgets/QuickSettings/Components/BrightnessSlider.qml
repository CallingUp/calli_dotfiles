import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Core
import qs.Core.Components

ThemedSlider {
    id: root

    property int brightness: 0
    property bool isVisible: true

    function setBrightness(val) {
        let finalVal = Math.max(5, val);
        brightSetProc.command = ["brightnessctl", "s", finalVal + "%"];
        brightSetProc.running = true;
        root.brightness = finalVal;
    }

    value: root.brightness
    icon: "sun"
    onMoved: (val) => {
        return root.setBrightness(val);
    }
    onIconClicked: {
        if (root.brightness <= 5)
            root.setBrightness(100);
        else
            root.setBrightness(5);
    }

    Timer {
        // The setter updates the UI immediately; poll only for external changes.
        interval: 1000
        running: root.isVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!brightGetProc.running && !brightSetProc.running) brightGetProc.running = true
    }

    Process {
        id: brightGetProc

        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                var parts = data.split(",");
                if (parts.length >= 4) {
                    var pct = parts[3];
                    if (pct.endsWith("%"))
                        pct = pct.substring(0, pct.length - 1);

                    if (!root.pressed)
                        root.brightness = parseInt(pct);

                }
            }
        }

    }

    Process {
        id: brightSetProc
        onExited: {
            if (root.isVisible && !root.pressed && !brightGetProc.running)
                brightGetProc.running = true;
        }
    }

}
