import QtQuick
import Quickshell.Io

// One PipeWire/Cava reader for the entire shell. Both the compact bar and its
// expanding island consume these same levels, so the waveform survives the
// geometry handoff without spawning another process.
Item {
    id: root

    property bool active: true
    property int barCount: 10
    property var levels: []

    function levelFor(values, index) {
        if (!values || values.length === 0)
            return 0;

        const count = values.length;
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
        const normalized = (peak * 0.12 + average * 0.88) / 1000;
        return Math.max(0, Math.min(0.78, Math.pow(normalized, 1.25) * 0.78));
    }

    Process {
        id: cavaProcess
        command: ["cava", "-p", "/home/calli/.config/cava/config_waybar"]
        running: root.active
        onRunningChanged: if (!running) root.levels = []
        stdout: SplitParser {
            onRead: (data) => {
                const row = data.trim();
                if (!row)
                    return;
                const parsed = row.split(";").filter(part => part !== "").map(part => {
                    const value = Number(part);
                    return isNaN(value) ? 0 : value;
                });
                if (parsed.length === 0)
                    return;

                const previous = root.levels;
                const next = [];
                for (let i = 0; i < root.barCount; ++i) {
                    const target = root.levelFor(parsed, i);
                    const before = previous.length === root.barCount ? previous[i] : target;
                    next.push(before * 0.52 + target * 0.48);
                }
                root.levels = next;
            }
        }
    }
}
