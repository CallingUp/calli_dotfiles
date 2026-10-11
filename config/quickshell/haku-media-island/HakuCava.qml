import QtQuick
import Quickshell.Io

// Small, direct replacement for Waybar's cava module.  It intentionally keeps
// the user's existing config: its 28 split-stereo bands are sampled into ten
// bars, preserving the different left/right activity without widening the
// media capsule.
Item {
    id: root

    property color barColor: "#d9d8d9"
    property bool active: false
    property var levels: []
    property int barCount: 10

    implicitWidth: barCount * 3 + (barCount - 1) * 2
    implicitHeight: 18
    width: implicitWidth
    height: implicitHeight
    visible: active

    function levelFor(values, index) {
        if (!values || values.length === 0)
            return 0;

        const count = values.length;
        // Cava emits left bands followed by right bands when split_stereo is
        // enabled. Keep each visual half in its own channel instead of
        // averaging the two into a symmetric animation.
        const halfBars = Math.ceil(barCount / 2);
        const channel = index < halfBars ? 0 : 1;
        const localIndex = index < halfBars ? index : index - halfBars;
        const available = Math.max(1, Math.floor(count / 2));
        const start = channel * available + Math.floor(localIndex * available / halfBars);
        const end = channel * available + Math.max(Math.floor((localIndex + 1) * available / halfBars), 1);
        let peak = 0;
        let sum = 0;
        let used = 0;
        for (let i = start; i < Math.min(end, count); ++i) {
            const value = Number(values[i]) || 0;
            peak = Math.max(peak, value);
            sum += value;
            used += 1;
        }
        const average = used > 0 ? sum / used : 0;
        // `data_format=ascii` in the existing config emits 0..1000, not a
        // percentage.  The former 0..100 assumption made virtually every
        // band clamp to its maximum height.
        // Autosensitivity can put an isolated bin at 1000 in nearly every
        // bucket. Let the channel average drive the height, retain only a
        // small amount of peak detail, and reserve headroom so a continuous
        // maximum is impossible.
        const normalized = (peak * 0.12 + average * 0.88) / 1000;
        return Math.max(0, Math.min(0.78, Math.pow(normalized, 1.25) * 0.78));
    }

    Process {
        id: cavaProcess
        command: ["cava", "-p", "/home/calli/.config/cava/config_waybar"]
        running: root.active
        onRunningChanged: {
            if (!running)
                root.levels = [];
        }
        stdout: SplitParser {
            onRead: (data) => {
                const row = data.trim();
                if (!row)
                    return;
                const parsed = row.split(";").filter(part => part !== "").map(part => {
                    const value = Number(part);
                    return isNaN(value) ? 0 : value;
                });
                if (parsed.length > 0) {
                    const previous = root.levels;
                    const next = [];
                    for (let i = 0; i < root.barCount; ++i) {
                        const target = root.levelFor(parsed, i);
                        const before = previous.length === root.barCount ? previous[i] : target;
                        // Fast enough to follow percussion, but avoids the
                        // harsh single-frame jumps visible in the first build.
                        next.push(before * 0.52 + target * 0.48);
                    }
                    root.levels = next;
                }
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: root.barCount
            delegate: Item {
                required property int index
                width: 3
                height: root.height
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: Math.max(3, Math.min(root.height, 3 + (root.levels[index] || 0) * (root.height - 3)))
                    radius: 1.5
                    color: root.barColor
                    opacity: 0.92
                    Behavior on height { NumberAnimation { duration: 85; easing.type: Easing.OutQuad } }
                }
            }
        }
    }
}
