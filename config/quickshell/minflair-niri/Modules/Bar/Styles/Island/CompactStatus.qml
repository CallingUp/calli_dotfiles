import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root
    property var sink: Pipewire.defaultAudioSink
    property string brightness: "--"
    readonly property string volume: sink && sink.audio ? (sink.audio.muted ? "mute" : Math.round(sink.audio.volume * 100) + "%") : "--"
    implicitWidth: content.implicitWidth + 24
    PwObjectTracker { objects: [root.sink] }
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 10
        ThemedText { text: "CPU " + Math.round(SystemStats.cpuUsage) + "%"; color: Theme.accent }
        ThemedText { text: "RAM " + Math.round(SystemStats.memPercent) + "%" }
        ThemedText { text: SystemStats.cpuTemperature }
        ThemedText { text: "VOL " + root.volume }
        ThemedText { text: "☼ " + root.brightness; color: Theme.accent }
    }
    Process {
        id: brightnessQuery
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                root.brightness = fields.length > 3 ? fields[3] : "--";
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: { if (!brightnessQuery.running) brightnessQuery.running = true; } }
}
