import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Core
import qs.Core.Components

ColumnLayout {
    id: root
    property var source: Pipewire.defaultAudioSource
    readonly property var devices: Pipewire.nodes.values.filter(node => !node.isStream && node.audio)
    readonly property var outputs: devices.filter(node => node.isSink)
    readonly property var inputs: devices.filter(node => !node.isSink && !node.name.endsWith(".monitor"))
    spacing: Constants.sizeSm

    PwObjectTracker { objects: root.devices }

    Repeater {
        model: [
            {title: "Salida de audio", nodes: root.outputs, current: Pipewire.defaultAudioSink, output: true},
            {title: "Micrófono", nodes: root.inputs, current: Pipewire.defaultAudioSource, output: false}
        ]
        delegate: ColumnLayout {
            id: deviceRow
            required property var modelData
            Layout.fillWidth: true
            spacing: 4
            ThemedText { text: deviceRow.modelData.title; color: Theme.muted }
            ComboBox {
                id: devicePicker
                Layout.fillWidth: true
                implicitHeight: 32
                model: deviceRow.modelData.nodes.map(node => ({label: node.description || node.nickname || node.name, node: node}))
                textRole: "label"
                currentIndex: deviceRow.modelData.nodes.findIndex(node => node === deviceRow.modelData.current)
                enabled: count > 0
                displayText: count > 0 ? currentText : "Sin dispositivos"
                font.family: Constants.fontFamily
                font.pixelSize: Constants.sizeSm
                palette.window: "#080808"
                palette.base: "#080808"
                palette.button: "#080808"
                palette.text: Theme.fg
                palette.buttonText: Theme.fg
                palette.highlight: Theme.accent
                palette.highlightedText: "#000000"
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06)
                    border.width: 1
                    border.color: devicePicker.hovered ? Theme.accent : Theme.border
                }
                onActivated: index => {
                    const node = model[index].node;
                    if (deviceRow.modelData.output) Pipewire.preferredDefaultAudioSink = node;
                    else Pipewire.preferredDefaultAudioSource = node;
                }
            }
        }
    }

    ThemedSlider {
        Layout.fillWidth: true
        enabled: root.source && root.source.audio && !root.source.audio.muted
        value: root.source && root.source.audio ? Math.round(root.source.audio.volume * 100) : 0
        icon: root.source && root.source.audio && root.source.audio.muted ? "microphone-off" : "microphone"
        onMoved: val => { if (root.source && root.source.audio) root.source.audio.volume = val / 100; }
        onIconClicked: { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted; }
    }
}
